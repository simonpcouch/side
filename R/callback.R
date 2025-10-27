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
  old_content <- if (file_exists) {
    readLines(path, warn = FALSE)
  } else {
    character(0)
  }

  tryCatch({
    if (str_replace_mode) {
      result <- handle_str_replace(old_content, old_str, new_str, path)
    } else if (insert_mode) {
      result <- handle_insert(old_content, insert_line, new_str, path)
    } else {
      return(format(htmltools::as.tags(shinychat::contents_shinychat(request))))
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

    format(card)
  }, error = function(e) {
    format(htmltools::as.tags(shinychat::contents_shinychat(request)))
  })
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
