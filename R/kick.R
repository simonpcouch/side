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
    client <- btw::btw_client(path_btw = main_config)
  }

  shinychat::chat_app(client, ...)
}
