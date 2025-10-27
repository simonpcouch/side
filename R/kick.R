#' Launch the `side::kick()` coding agent
#'
#' @param client An [ellmer::Chat] client or provider/model string
#' (e.g., `"anthropic/claude-sonnet-4-5"`) to power the `side::kick()` app.
#' @param ... Currently ignored.
#' @param host A character string specifying the host on which to run the app.
#'   Defaults to the value of `getOption("shiny.host", "127.0.0.1")`.
#'
#' @return
#' Launches a shiny application as a background job in RStudio. The application
#' is displayed in the RStudio viewer pane.
#'
#' @details
#' This function requires RStudio and will error if not running in RStudio.
#' The app runs as a background job, leaving the console free for other work.
#'
#' @export
kick <- function(client = NULL, ..., host = getOption("shiny.host", "127.0.0.1")) {
  rstudioapi::verifyAvailable()

  if (!is.null(client)) {
    withr::local_options(side.client = client)
  }

  port <- find_available_port()
  env_port <- find_available_port()
  env_url <- generate_env_server_url(env_port)

  launch_env_server(env_url)

  app_dir <- create_kick_dir(env_url)

  run_in_background(app_dir, "side", host, port)

  open_app_in_viewer(host, port)
}

kick_client <- function(call = rlang::caller_env()) {
  main_config <- system.file("agents", "main.md", package = "side")
  if (!file.exists(main_config)) {
    cli::cli_abort(
      "Could not find main agent configuration at {.path {main_config}}",
      call = call
    )
  }

  prompt_path <- append_skills(main_config)
  btw::btw_client(path_btw = prompt_path)
}

append_skills <- function(prompt_path) {
  main_prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
  skills_section <- format_skills_section()

  if (!nzchar(skills_section)) {
    return(prompt_path)
  }

  full_prompt <- paste0(main_prompt, "\n\n", skills_section)

  temp_prompt <- tempfile(fileext = ".md")
  writeLines(full_prompt, temp_prompt)

  temp_prompt
}

find_available_port <- function() {
  safe_ports <- setdiff(3000:8000, c(3659, 4045, 5060, 5061, 6000, 6566, 6665:6669, 6697))
  sample(safe_ports, 1)
}

create_kick_dir <- function(env_url) {
  dir <- normalizePath(tempdir(), winslash = "/")
  app_file <- create_kick_file(env_url)
  file.copy(app_file, file.path(dir, "app.R"), overwrite = TRUE)
  dir
}

create_kick_file <- function(env_url) {
  template_path <- system.file("client.R", package = "side")
  template <- paste(readLines(template_path, warn = FALSE), collapse = "\n")

  main_config <- system.file("agents", "main.md", package = "side")
  prompt_path <- append_skills(main_config)
  client_code <- fetch_side_client(prompt_path)

  app_code <- template
  app_code <- gsub("{{client_code}}", client_code, app_code, fixed = TRUE)
  app_code <- gsub("{{env_url}}", env_url, app_code, fixed = TRUE)

  temp_file <- tempfile(fileext = ".R")
  writeLines(app_code, temp_file)
  temp_file
}

run_in_background <- function(app_dir, job_name, host, port) {
  job_script <- tempfile(fileext = ".R")
  writeLines(
    glue::glue("shiny::runApp(appDir = '{app_dir}', port = {port}, host = '{host}')"),
    job_script
  )

  rstudioapi::jobRunScript(job_script, name = job_name)
}

open_app_in_viewer <- function(host, port) {
  url <- glue::glue("http://{host}:{port}")
  translated_url <- rstudioapi::translateLocalUrl(url, absolute = TRUE)

  wait_for_app_launch(translated_url)

  rstudioapi::viewer(translated_url)

  rstudioapi::executeCommand("activateConsole")
}

wait_for_app_launch <- function(url, max_seconds = 10) {
  start_time <- Sys.time()

  while (difftime(Sys.time(), start_time, units = "secs") < max_seconds) {
    result <- tryCatch(
      {
        httr2::request(url) |>
          httr2::req_perform()
        return(invisible(NULL))
      },
      error = function(e) {
        NULL
      }
    )

    Sys.sleep(0.2)
  }

  cli::cli_abort("App failed to start within {max_seconds} seconds")
}
