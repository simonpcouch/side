#' A coding agent for RStudio
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
#'
#' @section Choosing a model:
#'
#' `side::kick()` can use any model provider available in [ellmer::chat()] to
#' power the application. The app uses the `side.client` option (or the
#' `side::kick(client)` argument if you prefer) to configure the ellmer Chat
#' that powers the app; that option can be set to any [ellmer::Chat] object.
#'
#' When you call `kick()` without a client configured, a setup flow will
#' guide you through selecting a model. The setup flow will:
#'
#' 1. Check which providers are available based on your API keys (stored in
#'    environment variables) from a preferred subset of providers.
#' 2. Allow you to select from available providers.
#' 3. Ask if you want to save this configuration a) just for the current R
#'    session or b) in this _and_ future R sessions (by adding it to
#'    your `.Rprofile`).
#'
#' You can also configure a client manually by setting the `side.client` option:
#'
#' ```r
#' # For the current session only
#' options(side.client = ellmer::chat_anthropic(model = "claude-sonnet-4-5"))
#'
#' # In .Rprofile for all sessions
#' usethis::edit_r_profile()
#' # Then add:
#' options(side.client = ellmer::chat_anthropic(model = "claude-sonnet-4-5"))
#' ```
#'
#' **`side::kick()` was developed with Claude Sonnet 4.5 in mind**; use that
#' model for best results. That said, any frontier non-thinking (or
#' quickly-thinking) model like GPT 4.1 or Gemini 2.5 Pro will do fine. As of
#' late 2025, I do not recommend using local (e.g. [chat_ollama()]) models, but
#' you can give it a try!
#'
#' @export
kick <- function(
  client = NULL,
  ...,
  host = getOption("shiny.host", "127.0.0.1")
) {
  rstudioapi::verifyAvailable()

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
