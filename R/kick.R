#' Launch the `side::kick()` coding agent
#'
#' @param client An optional [ellmer::Chat] client to use.
#' @param ... Additional arguments passed to [shinychat::chat_app()]
#'
#' @return
#' Launches a shiny application. The application is designed to be ran
#' in the full-height "Sidebar" as a chat pane.
#'
#' @export
kick <- function(client = NULL, ...) {
  if (is.null(client)) {
    main_config <- system.file("agents", "main.md", package = "side")
    if (!file.exists(main_config)) {
      cli::cli_abort(
        "Could not find main agent configuration at {.path {main_config}}",
        call = rlang::caller_env()
      )
    }
    
    prompt_path <- append_skills(main_config)
    client <- btw::btw_client(path_btw = prompt_path)
  }

  client$register_tool(tool_update_plan())
  client$register_tool(tool_fetch_skill())
  swap_read_text_file(client)
  swap_write_text_file(client)

  shinychat::chat_app(client, ...)
}

append_skills <- function(prompt_path) {
  main_prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
  skills_section <- format_skills_section()
  
  if (!nzchar(skills_section)) {
    return(prompt_path)
  }
  
  # Append skills section to the prompt
  full_prompt <- paste0(main_prompt, "\n\n", skills_section)
  
  # Create temporary file with full prompt
  temp_prompt <- tempfile(fileext = ".md")
  writeLines(full_prompt, temp_prompt)
  
  temp_prompt
}
