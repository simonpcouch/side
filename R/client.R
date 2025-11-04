fetch_side_client <- function(prompt_path) {
  side_client_opt <- getOption("side.client")

  provider_model <- if (is.null(side_client_opt)) {
    NULL
  } else if (is.character(side_client_opt)) {
    side_client_opt
  } else if (inherits(side_client_opt, "Chat")) {
    provider <- side_client_opt$get_provider()
    provider_short <- gsub("/", "_", tolower(provider@name))
    paste0(provider_short, "/", provider@model)
  } else {
    cli::cli_warn(c(
      "!" = "{.code side.client} option must be a Chat object or provider/model string.",
      "i" = "Falling back to default client."
    ))
    NULL
  }

  if (is.null(provider_model)) {
    return(glue::glue(
      "
    client <- ellmer::chat()
    system_prompt <- paste(readLines('{prompt_path}', warn = FALSE), collapse = '\\n')
    client$set_system_prompt(system_prompt)
    "
    ))
  }

  glue::glue(
    "
    client <- ellmer::chat('{provider_model}')
    system_prompt <- paste(readLines('{prompt_path}', warn = FALSE), collapse = '\\n')
    client$set_system_prompt(system_prompt)
  "
  )
}
