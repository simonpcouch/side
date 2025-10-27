read_text_file_impl <- function(path, line_start = 1, line_end = 1000, `_intent` = NULL) {
  check_string(path)

  if (!file.exists(path)) {
    cli::cli_abort(
      "Path {.path {path}} does not exist.",
      call = rlang::caller_env()
    )
  }

  if (!file.info(path)$isdir) {
    contents <- readLines(path, warn = FALSE, n = line_end)

    if (line_start > 1 && line_start <= length(contents)) {
      contents <- contents[line_start:min(line_end, length(contents))]
    } else if (line_start > length(contents)) {
      contents <- character(0)
    }

    contents_with_line_numbers <- sprintf("%d: %s",
                                          seq(line_start, length.out = length(contents)),
                                          contents)

    value <- paste(contents_with_line_numbers, collapse = "\n")

    file_ext <- tools::file_ext(path)
    display_value <- paste0("```", file_ext, "\n", value, "\n```")
  } else {
    cli::cli_abort(
      "Path {.path {path}} is a directory, not a file.",
      call = rlang::caller_env()
    )
  }

  ellmer::ContentToolResult(
    value = value,
    extra = list(
      path = path,
      display = list(
        markdown = display_value,
        title = htmltools::HTML(sprintf("Read <code>%s</code>", basename(path)))
      )
    )
  )
}

tool_read_text_file <- function() {
  ellmer::tool(
    read_text_file_impl,
    name = "read_text_file",
    description = paste(
      "Read a text file with line numbers.",
      "Each line is prefixed with its line number (e.g., '1: first line').",
      "Use line numbers when editing files with the write tool."
    ),
    arguments = list(
      path = ellmer::type_string(
        "Relative path to the file to read."
      ),
      line_start = ellmer::type_number(
        "Starting line to read (default: 1).",
        required = FALSE
      ),
      line_end = ellmer::type_number(
        "Ending line to read (default: 1000).",
        required = FALSE
      ),
      `_intent` = ellmer::type_string(
        "Brief description of why you're reading this file",
        required = FALSE
      )
    ),
    convert = FALSE
  )
}

swap_read_text_file <- function(client, socket_url = NULL) {
  tools <- client$get_tools()

  btw_read_name <- "btw_tool_files_read_text_file"
  if (btw_read_name %in% names(tools)) {
    tools[[btw_read_name]] <- NULL
    client$set_tools(tools)
  }

  custom_tool <- tool_read_text_file()

  if (!is.null(socket_url)) {
    custom_tool <- reroute_tool(custom_tool, socket_url)
  }

  client$register_tool(custom_tool)

  invisible(client)
}
