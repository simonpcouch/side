setup_tool_approval_callback <- function(
  client, 
  session = shiny::getDefaultReactiveDomain()
) {
  if (is.null(session)) {
    cli::cli_warn("Tool approval requires a Shiny session. Skipping approval setup.")
    return(invisible(client))
  }

  client$on_tool_request(coro::async(function(request) {
    needs_approval <- requires_approval(request)

    if (!needs_approval) {
      return(invisible(NULL))
    }

    # Validate syntax before showing approval UI (no file I/O)
    if (request@name == "write_text_file") {
      args <- request@arguments
      tryCatch(
        {
          validate_write_text_file_syntax(
            args$path,
            args$insert_line,
            args$new_str,
            args$old_str,
            call = rlang::current_env()
          )
        },
        error = function(e) {
          ellmer::tool_reject(conditionMessage(e))
        }
      )
    }

    request_id <- request@id

    if (is.null(session) || is.null(session$userData$approval_resolvers)) {
      return(invisible(NULL))
    }

    approval_promise <- promises::promise(function(resolve, reject) {
      session$userData$approval_resolvers$set(request_id, resolve)
    })

    timeout_promise <- promises::promise(function(resolve, reject) {
      later::later(function() resolve(FALSE), delay = 300)
    })

    show_approval_ui_message(request, request_id, session)

    response <- coro::await(promises::promise_race(approval_promise, timeout_promise))

    session$userData$approval_resolvers$remove(request_id)

    if (!response) {
      ellmer::tool_reject("The user rejected the tool request.")
    }

    invisible(NULL)
  }))

  invisible(client)
}

requires_approval <- function(request) {
  tool_name <- request@name

  if (tool_name == "write_text_file") {
    return(TRUE)
  }

  if (tool_name == "shell") {
    command <- request@arguments$command
    if (!is.null(command) && is_dangerous_command(command)) {
      return(TRUE)
    }
  }

  FALSE
}

show_approval_ui_message <- function(request, request_id, session) {
  preview_html <- create_approval_preview(request)

  session$sendCustomMessage("show-approval-message", list(
    request_id = request_id,
    tool_card_html = preview_html
  ))
}

create_approval_preview <- function(request) {
  if (request@name == "write_text_file") {
    return(create_write_file_preview(request))
  }

  if (request@name == "shell") {
    return(create_shell_preview(request))
  }

  tool_card <- shinychat::contents_shinychat(request)
  format(htmltools::as.tags(tool_card))
}

create_write_file_preview <- function(request) {
  args <- request@arguments

  path <- args$path
  insert_line <- args$insert_line
  new_str <- args$new_str
  old_str <- args$old_str
  intent <- args$`_intent`

  str_replace_mode <- !is.null(old_str) && !is.null(new_str)
  insert_mode <- !is.null(insert_line) && !is.null(new_str)

  file_exists <- file.exists(path)

  if (!file_exists && str_replace_mode) {
    return(create_write_file_summary_preview(request))
  }

  old_content <- if (file_exists) {
    readLines(path, warn = FALSE)
  } else {
    character(0)
  }

  # Validate str_replace mode: check that old_str exists and is unique
  if (str_replace_mode && file_exists) {
    old_content_text <- paste(old_content, collapse = "\n")
    matches <- gregexpr(old_str, old_content_text, fixed = TRUE)[[1]]

    if (length(matches) == 1 && matches[1] == -1) {
      return(create_write_file_summary_preview(request))
    }

    if (length(matches) > 1) {
      return(create_write_file_summary_preview(request))
    }
  }

  # Validate insert mode: check insert_line is in valid range
  if (insert_mode && file_exists) {
    if (insert_line < 0 || insert_line > length(old_content)) {
      return(create_write_file_summary_preview(request))
    }
  }

  # Try to generate the full diff preview
  tryCatch({
    if (str_replace_mode) {
      result <- handle_str_replace(old_content, old_str, new_str, path)
    } else {
      result <- handle_insert(old_content, insert_line, new_str, path)
    }

  diff_text <- create_diff_display(
    result$removed_lines,
    result$added_lines,
    path,
    result$context,
    result$context_before,
    result$context_after
  )

  diff_md <- paste(diff_text, collapse = "\n")

  title <- htmltools::HTML(sprintf(
    "%s <code>%s</code>",
    result$operation,
    basename(path)
  ))

  # Create the preview content with diff
  preview_content <- htmltools::tagList(
    htmltools::tags$div(
      class = "write-file-preview",
      style = "padding: 0.5rem;",
      htmltools::tags$div(
        class = "preview-title",
        style = "font-weight: 600; margin-bottom: 0.5rem;",
        title
      ),
      htmltools::tag(
        "shiny-markdown-stream",
        list(
          content = diff_md,
          "content-type" = "markdown",
          streaming = "false"
        )
      )
    )
  )

  # Build a simple container with just the preview content (no card header)
  card <- htmltools::tags$div(
    class = "approval-preview-content",
    style = "padding: 0.5rem;",
    preview_content
  )

  formatted <- format(card)
    formatted
  }, error = function(e) {
    create_write_file_summary_preview(request)
  })
}

create_write_file_summary_preview <- function(request) {
  args <- request@arguments
  path <- args$path
  insert_line <- args$insert_line
  new_str <- args$new_str
  old_str <- args$old_str

  str_replace_mode <- !is.null(old_str) && !is.null(new_str)
  insert_mode <- !is.null(insert_line) && !is.null(new_str)

  old_str_lines <- if (str_replace_mode) strsplit(old_str, "\n", fixed = TRUE)[[1]] else character(0)
  new_str_lines <- strsplit(new_str, "\n", fixed = TRUE)[[1]]

  operation <- if (str_replace_mode) "Edit" else if (insert_mode) "Edit/Create" else "Unknown"

  context <- if (str_replace_mode) {
    "str_replace"
  } else if (insert_mode) {
    sprintf("insert at line %d", insert_line)
  } else {
    "unknown"
  }

  diff_text <- create_diff_display(
    removed_lines = old_str_lines,
    added_lines = new_str_lines,
    path = path,
    context = context,
    context_before = character(0),
    context_after = character(0)
  )

  diff_md <- paste(diff_text, collapse = "\n")

  title <- htmltools::HTML(sprintf(
    "%s <code>%s</code>",
    operation,
    basename(path)
  ))

  preview_content <- htmltools::tagList(
    htmltools::tags$div(
      class = "write-file-preview",
      style = "padding: 0.5rem;",
      htmltools::tags$div(
        class = "preview-title",
        style = "font-weight: 600; margin-bottom: 0.5rem;",
        title
      ),
      htmltools::tag(
        "shiny-markdown-stream",
        list(
          content = diff_md,
          "content-type" = "markdown",
          streaming = "false"
        )
      )
    )
  )

  card <- htmltools::tags$div(
    class = "approval-preview-content",
    style = "padding: 0.5rem;",
    preview_content
  )

  format(card)
}

create_shell_preview <- function(request) {
  args <- request@arguments
  command <- args$command
  intent <- args$`_intent`

  preview_md <- sprintf("```bash\n%s\n```", command)

  title <- "Execute Shell Command"
  if (!is.null(intent) && nchar(intent) > 0) {
    title <- sprintf("%s: %s", title, intent)
  }

  tool_card <- shinychat:::new_tool_card(
    "request",
    request_id = request@id,
    tool_name = request@name,
    tool_title = title,
    intent = if (!is.null(intent)) intent,
    expanded = TRUE
  )

  card_html <- format(htmltools::as.tags(tool_card))

  preview_content <- htmltools::tags$div(
    class = "shell-command-preview",
    htmltools::tags$div(
      class = "preview-title",
      style = "font-weight: 600; margin-bottom: 0.5rem;",
      "Command to execute:"
    ),
    htmltools::tag(
      "shiny-markdown-stream",
      list(
        content = preview_md,
        "content-type" = "markdown",
        streaming = "false"
      )
    )
  )

  preview_html <- format(preview_content)

  card_html <- sub(
    '<div class="shiny-tool-request__arguments">.*?</div>',
    preview_html,
    card_html
  )

  card_html
}

hide_approval_ui_message <- function(request_id, session) {
  session$sendCustomMessage("hide-approval-message", list(
    request_id = request_id
  ))
}
