#' A coding agent for RStudio
#'
#' @description
#' `side::kick()` is a coding agent for data science in RStudio,
#' implemented entirely in R. Think of it something like Claude Code
#' or Codex; it's situated in your project directory and can use tools
#' to explore its surroundings. In addition, though, it has
#' tools that allow it to explore your active R session and run R code
#' in it.
#'
#' To get started with `side::kick()`, just run the function--it will
#' walk you through the next steps! #' See
#' `vignettes("side", package = "side")` for more on getting started with
#' `side::kick()`, including choosing a model and customizing behavior.
#'
#' This function requires RStudio and will not launch in Positron or other
#' R environments.
#'
#' @param client An [ellmer::Chat] client to power the `side::kick()` app.
#'   See the "Choosing a model" section below to learn more.
#' @param ... Currently ignored.
#' @param host A character string specifying the host on which to run the app.
#'   Defaults to the value of `getOption("shiny.host", "127.0.0.1")`.
#'
#' @return
#' Launches a shiny application as a background job in RStudio. The application
#' is displayed in the RStudio viewer pane and this function will return after
#' the application is launched successfully.
#' @export
kick <- function(
  client = NULL,
  ...,
  host = getOption("shiny.host", "127.0.0.1")
) {
  check_in_rstudio()

  if (!is.null(client)) {
    withr::local_options(side.client = client)
  }

  if (is.null(getOption("side.client"))) {
    setup_client()
  }

  port <- find_available_port()
  env_port <- find_available_port()
  env_url <- generate_env_server_url(env_port)

  launch_env_server(env_url)

  app_dir <- create_kick_dir(env_url)

  run_in_background(app_dir, "side", host, port)

  open_app_in_viewer(host, port)
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

append_user_context <- function(prompt_path, working_dir) {
  context_files <- c("CLAUDE.md", "btw.md", "llms.txt", "AGENTS.md")

  found_file <- NULL
  for (filename in context_files) {
    full_path <- file.path(working_dir, filename)
    if (file.exists(full_path)) {
      found_file <- list(name = filename, path = full_path)
      break
    }
  }

  if (is.null(found_file)) {
    return(prompt_path)
  }

  main_prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
  user_context <- paste(
    readLines(found_file$path, warn = FALSE),
    collapse = "\n"
  )

  context_section <- paste0(
    "\n\n## User context\n\n",
    "The following context has been provided by the user in ",
    found_file$name,
    ":\n\n",
    "{userContext}\n",
    user_context,
    "\n",
    "{/userContext}"
  )

  full_prompt <- paste0(main_prompt, context_section)

  temp_prompt <- tempfile(fileext = ".md")
  writeLines(full_prompt, temp_prompt)

  temp_prompt
}

find_available_port <- function() {
  safe_ports <- setdiff(
    3000:8000,
    c(3659, 4045, 5060, 5061, 6000, 6566, 6665:6669, 6697)
  )
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

  working_dir <- normalizePath(getwd(), winslash = "/")
  main_config <- system.file("agents", "main.md", package = "side")
  prompt_path <- append_skills(main_config)
  prompt_path <- append_user_context(prompt_path, working_dir)
  prompt_path <- normalizePath(prompt_path, winslash = "/")
  client_code <- fetch_side_client(prompt_path)

  persist <- should_persist()

  app_code <- template
  app_code <- gsub("{{client_code}}", client_code, app_code, fixed = TRUE)
  app_code <- gsub("{{env_url}}", env_url, app_code, fixed = TRUE)
  app_code <- gsub("{{working_dir}}", working_dir, app_code, fixed = TRUE)
  app_code <- gsub("{{persist}}", as.character(persist), app_code, fixed = TRUE)

  temp_file <- tempfile(fileext = ".R")
  writeLines(app_code, temp_file)
  temp_file
}

run_in_background <- function(app_dir, job_name, host, port) {
  job_script <- tempfile(fileext = ".R")
  writeLines(
    glue::glue(
      "shiny::runApp(appDir = '{app_dir}', port = {port}, host = '{host}')"
    ),
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

check_in_rstudio <- function(call = rlang::caller_env()) {
  rstudioapi::verifyAvailable()

  if (identical(Sys.getenv("POSITRON"), "1")) {
    cli::cli_abort(
      c(
        "{.fn side::kick} requires RStudio and is not supported in Positron."
      ),
      call = call
    )
  }
}
