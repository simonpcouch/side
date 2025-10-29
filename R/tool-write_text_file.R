validate_write_text_file_syntax <- function(path, insert_line, new_str, old_str, call = rlang::caller_env()) {
  str_replace_mode <- !is.null(old_str) && !is.null(new_str)
  insert_mode <- !is.null(insert_line) && !is.null(new_str)

  if (str_replace_mode && insert_mode) {
    cli::cli_abort(
      "Cannot use both str_replace mode (old_str/new_str) and insert mode (insert_line/new_str) at the same time.",
      call = call
    )
  }

  if (!str_replace_mode && !insert_mode) {
    cli::cli_abort(
      "Must provide either (old_str + new_str) for replacement or (insert_line + new_str) for insertion.",
      call = call
    )
  }

  invisible(NULL)
}

validate_write_text_file_request <- function(path, insert_line, new_str, old_str, call = rlang::caller_env()) {
  validate_write_text_file_syntax(path, insert_line, new_str, old_str, call = call)

  str_replace_mode <- !is.null(old_str) && !is.null(new_str)
  insert_mode <- !is.null(insert_line) && !is.null(new_str)
  file_exists <- file.exists(path)

  if (!file_exists && str_replace_mode) {
    cli::cli_abort(
      "Cannot use str_replace mode on a file that doesn't exist. Use insert mode with insert_line=0 to create a new file.",
      call = call
    )
  }

  old_content <- if (file_exists) readLines(path, warn = FALSE) else character(0)

  if (str_replace_mode && file_exists) {
    old_content_text <- paste(old_content, collapse = "\n")
    matches <- gregexpr(old_str, old_content_text, fixed = TRUE)[[1]]

    if (length(matches) == 1 && matches[1] == -1) {
      cli::cli_abort(
        "No match found for old_str in {.path {path}}. Make sure the text matches exactly, including whitespace.",
        call = call
      )
    }

    if (length(matches) > 1) {
      cli::cli_abort(
        "Found {length(matches)} matches for old_str in {.path {path}}. Please provide more context to make the match unique.",
        call = call
      )
    }
  }

  if (insert_mode && file_exists && (insert_line < 0 || insert_line > length(old_content))) {
    cli::cli_abort(
      "insert_line must be between 0 and {length(old_content)} (0 = beginning, {length(old_content)} = end).",
      call = call
    )
  }

  old_content
}

write_text_file_impl <- function(path, insert_line = NULL, new_str = NULL, old_str = NULL, `_intent` = NULL) {
  check_string(path)

  old_content <- validate_write_text_file_request(path, insert_line, new_str, old_str, call = rlang::caller_env())

  result <- if (!is.null(old_str) && !is.null(new_str)) {
    handle_str_replace(old_content, old_str, new_str, path)
  } else {
    handle_insert(old_content, insert_line, new_str, path)
  }

  dir_path <- dirname(path)
  if (dir_path != "." && !dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }

  writeLines(result$new_content, path)

  diff_text <- create_diff_display(
    result$removed_lines,
    result$added_lines,
    path,
    result$context,
    result$context_before,
    result$context_after
  )

  value_text <- sprintf(
    "%s %s (%d lines total)",
    result$operation,
    path,
    length(result$new_content)
  )

  ellmer::ContentToolResult(
    value = value_text,
    extra = list(
      path = path,
      operation = result$operation,
      display = list(
        markdown = paste(diff_text, collapse = "\n"),
        title = htmltools::HTML(sprintf(
          "\u2705 %s <code>%s</code>",
          result$operation,
          basename(path)
        )),
        icon = tool_icon("file-save"),
        show_request = FALSE,
        open = TRUE
      )
    )
  )
}

handle_str_replace <- function(old_content, old_str, new_str, path) {
  old_content_text <- paste(old_content, collapse = "\n")
  matches <- gregexpr(old_str, old_content_text, fixed = TRUE)[[1]]

  new_content_text <- sub(old_str, new_str, old_content_text, fixed = TRUE)
  new_content <- strsplit(new_content_text, "\n", fixed = TRUE)[[1]]

  old_str_lines <- strsplit(old_str, "\n", fixed = TRUE)[[1]]
  new_str_lines <- strsplit(new_str, "\n", fixed = TRUE)[[1]]

  match_pos <- matches[1]
  chars_before <- substr(old_content_text, 1, match_pos - 1)
  start_line <- length(strsplit(chars_before, "\n", fixed = TRUE)[[1]])
  end_line <- start_line + length(old_str_lines) - 1

  context_before <- if (start_line > 1) {
    old_content[max(1, start_line - 3):(start_line - 1)]
  } else {
    character(0)
  }

  context_after <- if (end_line < length(old_content)) {
    old_content[(end_line + 1):min(length(old_content), end_line + 3)]
  } else {
    character(0)
  }

  list(
    new_content = new_content,
    removed_lines = old_str_lines,
    added_lines = new_str_lines,
    operation = "Edit",
    context = "str_replace",
    context_before = context_before,
    context_after = context_after
  )
}

handle_insert <- function(old_content, insert_line, new_str, path) {
  new_str_lines <- strsplit(new_str, "\n", fixed = TRUE)[[1]]

  new_content <- c(
    if (insert_line > 0) old_content[1:insert_line] else character(0),
    new_str_lines,
    if (insert_line < length(old_content)) old_content[(insert_line + 1):length(old_content)] else character(0)
  )

  operation <- if (length(old_content) == 0) {
    "Create"
  } else {
    "Edit"
  }

  context_before <- if (insert_line > 0 && length(old_content) > 0) {
    old_content[max(1, insert_line - 2):insert_line]
  } else {
    character(0)
  }

  context_after <- if (insert_line < length(old_content)) {
    old_content[(insert_line + 1):min(length(old_content), insert_line + 3)]
  } else {
    character(0)
  }

  list(
    new_content = new_content,
    removed_lines = character(0),
    added_lines = new_str_lines,
    operation = operation,
    context = sprintf("insert at line %d", insert_line),
    context_before = context_before,
    context_after = context_after
  )
}

create_diff_display <- function(removed_lines, added_lines, path, context, context_before = character(0), context_after = character(0)) {
  if (length(removed_lines) == 0 && length(added_lines) == 0) {
    return("No changes")
  }

  diff_lines <- c(
    paste0("  ", context_before),
    paste0("- ", removed_lines),
    paste0("+ ", added_lines),
    paste0("  ", context_after)
  )

  c(
    "```diff",
    sprintf("@@ %s: %s @@", basename(path), context),
    diff_lines,
    "```"
  )
}

tool_write_text_file <- function() {
  ellmer::tool(
    write_text_file_impl,
    name = "write_text_file",
    description = paste(
      "Write or edit text files that are requested by the user or required for their project.",
      "NEVER create files for internal purposes (planning, notes, scratch work).",
      "Use update_plan for tracking progress, not files.",
      "Always prefer editing existing files over creating new ones.",
      "",
      "You must use exactly one of two modes:",
      "1. insert (insert_line) mode (PREFERRED when no lines will be deleted): Insert text at a line number (use insert_line + new_str).",
      "   Use this when adding new content without removing existing lines.",
      "   Line numbers come from read_text_file output.",
      "2. replace (old_str) MODE: Replace exact text matches (use old_str + new_str).",
      "   Only use this when you need to remove or modify existing lines.",
      "   old_str must match exactly, including all whitespace and newlines.",
      "Always call read_text_file first to see line numbers and existing content."
    ),
    arguments = list(
      path = ellmer::type_string(
        "Relative path to the file to write or edit."
      ),
      insert_line = ellmer::type_number(
        "For INSERT mode (PREFERRED when no lines are deleted): Line number after which to insert new_str (0 = beginning of file). Creates file if it doesn't exist.",
        required = FALSE
      ),
      new_str = ellmer::type_string(
        "The new text to insert or use as replacement. Required for both modes.",
        required = FALSE
      ),
      old_str = ellmer::type_string(
        "For REPLACE mode only: The exact text to find and replace. Must match exactly, including whitespace and newlines. Only use when removing/modifying existing lines.",
        required = FALSE
      ),
      `_intent` = ellmer::type_string(
        "Brief description of what changes you're making",
        required = FALSE
      )
    ),
    convert = FALSE
  )
}

swap_write_text_file <- function(client, socket_url = NULL) {
  tools <- client$get_tools()

  btw_write_name <- "btw_tool_files_write_text_file"
  if (btw_write_name %in% names(tools)) {
    tools[[btw_write_name]] <- NULL
    client$set_tools(tools)
  }

  custom_tool <- tool_write_text_file()

  if (!is.null(socket_url)) {
    custom_tool <- reroute_tool(custom_tool, socket_url)
  }

  client$register_tool(custom_tool)

  invisible(client)
}
