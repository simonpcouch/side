setup_tool_approval_callback <- function(
  client, 
  session = shiny::getDefaultReactiveDomain()
) {
  if (is.null(session)) {
    cli::cli_warn("Tool approval requires a Shiny session. Skipping approval setup.")
    return(invisible(client))
  }

  client$on_tool_request(coro::async(function(request) {
    needs_approval <- requires_approval(request)

    if (!needs_approval) {
      return(invisible(NULL))
    }

    request_id <- request@id

    if (is.null(session) || is.null(session$userData$approval_resolvers)) {
      return(invisible(NULL))
    }

    approval_promise <- promises::promise(function(resolve, reject) {
      session$userData$approval_resolvers$set(request_id, resolve)
    })

    timeout_promise <- promises::promise(function(resolve, reject) {
      later::later(function() resolve(FALSE), delay = 300)
    })

    show_approval_ui_message(request, request_id, session)

    response <- coro::await(promises::promise_race(approval_promise, timeout_promise))

    session$userData$approval_resolvers$remove(request_id)

    if (!response) {
      ellmer::tool_reject("The user rejected the tool request.")
    }

    invisible(NULL)
  }))

  invisible(client)
}

requires_approval <- function(request) {
  tool_name <- request@name

  if (tool_name == "write_text_file") {
    return(TRUE)
  }

  if (tool_name == "shell") {
    command <- request@arguments$command
    if (!is.null(command) && is_dangerous_command(command)) {
      return(TRUE)
    }
  }

  FALSE
}

show_approval_ui_message <- function(request, request_id, session) {
  reason <- get_approval_reason(request)

  session$sendCustomMessage("show-approval-message", list(
    request_id = request_id,
    tool_name = request@name,
    reason = as.character(reason)
  ))
}

hide_approval_ui_message <- function(request_id, session) {
  session$sendCustomMessage("hide-approval-message", list(
    request_id = request_id
  ))
}

get_approval_reason <- function(request) {
  if (request@name == "write_text_file") {
    path <- request@arguments$path %||% "a file"
    return(sprintf("This will write to: %s", path))
  }

  if (request@name == "shell") {
    command <- request@arguments$command
    return(sprintf("This will execute: %s", command))
  }

  "This action requires approval."
}
