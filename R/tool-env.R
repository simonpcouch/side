reroute_env_tool <- function(tool, socket_url) {
  check_inherits(tool, "ellmer::ToolDef")
  check_string(socket_url)

  tool_fun <- S7::S7_data(tool)

  rerouted_fun <- rlang::new_function(
    rlang::fn_fmls(tool_fun),
    rlang::expr({
      args <- as.list(environment())

      sock <- nanonext::socket("req", dial = !!socket_url)
      on.exit(close(sock), add = TRUE)

      ctx <- nanonext::context(sock)

      request <- list(
        tool_name = !!tool@name,
        arguments = args
      )

      response <- nanonext::request(
        ctx,
        data = request,
        timeout = 5000
      )

      nanonext::call_aio(response)

      result <- response$data

      if (!is.null(result$error)) {
        cli::cli_abort(result$error, call = rlang::caller_env())
      }

      result$value
    }),
    env = rlang::fn_env(tool_fun)
  )

  S7::S7_data(tool) <- rerouted_fun
  tool
}

swap_env_tools <- function(client, socket_url) {
  check_inherits(client, "Chat")
  check_string(socket_url)

  tools <- client$get_tools()
  env_tool_names <- names(btw::btw_tools("env"))

  for (tool_name in env_tool_names) {
    if (tool_name %in% names(tools)) {
      tools[[tool_name]] <- reroute_env_tool(tools[[tool_name]], socket_url)
    }
  }

  client$set_tools(tools)
  invisible(client)
}

swap_file_tools <- function(client, socket_url) {
  check_inherits(client, "Chat")
  check_string(socket_url)

  tools <- client$get_tools()
  file_tool_names <- names(btw::btw_tools("files"))

  for (tool_name in file_tool_names) {
    if (tool_name %in% names(tools)) {
      tools[[tool_name]] <- reroute_env_tool(tools[[tool_name]], socket_url)
    }
  }

  client$set_tools(tools)
  invisible(client)
}

start_env_tool_server <- function(url) {
  check_string(url)

  sock <- nanonext::socket("rep", listen = url)

  env_tools <- btw::btw_tools("env")
  file_tools <- btw::btw_tools("files")
  custom_read <- tool_read_text_file()
  custom_write <- tool_write_text_file()
  code_search <- btw::btw_tool_files_code_search

  all_tools <- c(
    env_tools,
    file_tools,
    list(
      read_text_file = custom_read,
      write_text_file = custom_write,
      btw_tool_files_code_search = code_search
    )
  )

  the$env_server_socket <- sock
  the$env_server_active <- TRUE

  later::later(
    function() {
      service_env_requests(sock, all_tools)
    },
    delay = 0.1
  )

  invisible(sock)
}

service_env_requests <- function(sock, all_tools) {
  if (!isTRUE(the$env_server_active)) {
    return()
  }

  ctx <- nanonext::context(sock)

  nanonext::reply(
    ctx,
    execute = function(request) {
      tool_name <- request$tool_name
      args <- request$arguments

      if (tool_name %in% names(all_tools)) {
        tool <- all_tools[[tool_name]]
        tool_fun <- S7::S7_data(tool)

        tryCatch(
          {
            result <- do.call(tool_fun, args, envir = .GlobalEnv)
            list(value = result, error = NULL)
          },
          error = function(e) {
            list(value = NULL, error = conditionMessage(e))
          }
        )
      } else {
        list(value = NULL, error = paste0("Unknown tool: ", tool_name))
      }
    },
    timeout = 100
  )

  later::later(
    function() {
      service_env_requests(sock, all_tools)
    },
    delay = 0.1
  )
}

stop_env_tool_server <- function() {
  the$env_server_active <- FALSE

  if (!is.null(the$env_server_socket)) {
    close(the$env_server_socket)
    the$env_server_socket <- NULL
  }

  invisible(NULL)
}

generate_env_server_url <- function(port) {
  sprintf("tcp://127.0.0.1:%d", port)
}

launch_env_server <- function(url) {
  check_string(url)

  start_env_tool_server(url)

  wait_for_env_server(url)

  invisible(url)
}

wait_for_env_server <- function(url, max_seconds = 5) {
  start_time <- Sys.time()

  while (difftime(Sys.time(), start_time, units = "secs") < max_seconds) {
    result <- tryCatch(
      {{
        sock <- nanonext::socket("req", dial = url)
        on.exit(close(sock), add = TRUE)
        ctx <- nanonext::context(sock)

        test_request <- list(
          tool_name = "btw_tool_env_describe_environment",
          arguments = list(items = NULL, `_intent` = "")
        )

        response <- nanonext::request(ctx, data = test_request, timeout = 100)
        nanonext::call_aio(response)

        return(invisible(NULL))
      }},
      error = function(e) {
        NULL
      }
    )

    Sys.sleep(0.1)
  }

  cli::cli_abort("Env tool server failed to start within {max_seconds} seconds")
}
