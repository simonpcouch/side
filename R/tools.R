sidekick_tools <- function(socket_url = NULL) {
  tools_to_reroute <- c(
    btw::btw_tools("env"),
    btw::btw_tools("btw_tool_files_list_files"),
    btw::btw_tools("btw_tool_files_code_search"),
    list(
      read_text_file = tool_read_text_file(),
      write_text_file = tool_write_text_file(),
      shell = tool_shell(),
      run_r_code = tool_run_r_code()
    )
  )

  if (!is.null(socket_url)) {
    tools_to_reroute <- lapply(
      tools_to_reroute,
      reroute_tool,
      socket_url = socket_url
    )
  }

  if ("btw_tool_files_code_search" %in% names(tools_to_reroute)) {
    tools_to_reroute[[
      "btw_tool_files_code_search"
    ]] <- silence_tool(tools_to_reroute[["btw_tool_files_code_search"]])
  }

  c(
    btw::btw_tools("docs"),
    btw::btw_tools("github"),
    btw::btw_tools("ide"),
    btw::btw_tools("search"),
    btw::btw_tools("session"),
    btw::btw_tools("web"),
    tools_to_reroute,
    list(
      tool_update_plan = tool_update_plan(),
      tool_fetch_skill = tool_fetch_skill()
    )
  )
}
