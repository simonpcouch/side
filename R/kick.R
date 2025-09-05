#' Launch the side package development assistant
#'
#' @param client An optional [ellmer::Chat] client to use. If not provided,
#'   creates a btw client using the main agent configuration.
#' @param ... Additional arguments passed to [shinychat::chat_app()]
#'
#' @return Launches a Shiny application for interactive package development
#'   assistance. Returns the result of [shinychat::chat_app()] invisibly.
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
    register_agent_researcher(client)
    register_agent_tester(client)
    client$register_tool(TodoWrite())
  }
  
  shinychat::chat_app(client, ...)
}

register_agent_researcher <- function(client) {
  researcher_config <- system.file("agents", "researcher.md", package = "side")
  if (file.exists(researcher_config)) {
    researcher_agent <- btw_tool_agent(
      name = "researcher",
      description = "Research agent for investigating R packages, documentation, and best practices. Use when you need to gather comprehensive information about packages, functions, or development practices.",
      title = "Research Assistant",
      client = btw::btw_client(path_btw = researcher_config)
    )
    client$register_tool(researcher_agent)
  }
}

register_agent_tester <- function(client) {
  tester_config <- system.file("agents", "tester.md", package = "side")
  if (file.exists(tester_config)) {
    tester_agent <- btw_tool_agent(
      name = "tester",
      description = "Test writing agent for creating testthat unit tests. Use when you need to generate comprehensive tests for R package functions.",
      title = "Test Writer",
      client = btw::btw_client(path_btw = tester_config)
    )
    client$register_tool(tester_agent)
  }
}