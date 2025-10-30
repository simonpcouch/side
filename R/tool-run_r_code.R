run_r_code_impl <- function(code, persist = FALSE, `_intent` = NULL) {
  check_string(code)

  messages <- character()
  warnings <- character()
  error_msg <- NULL
  result <- NULL

  exec_env <- if (persist) {
    .GlobalEnv
  } else {
    new.env(parent = .GlobalEnv)
  }

  result <- tryCatch(
    withCallingHandlers(
      {
        eval(parse(text = code), envir = exec_env)
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      },
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      error_msg <<- conditionMessage(e)
      NULL
    }
  )
  
  if (!is.null(error_msg)) {
    error_lines <- strsplit(error_msg, "\n", fixed = TRUE)[[1]]
    error_commented <- paste0("#> ", error_lines, collapse = "\n")
    error_display <- sprintf("```r\n%s\n%s\n```", code, error_commented)

    return(ellmer::ContentToolResult(
      # Rather than providing `error = `, we use `value` to override shinychat
      # error display.
      value = paste0("Error: ", error_msg),
      extra = list(
        code = code,
        display = list(
          markdown = error_display,
          title = htmltools::HTML("\u274c Run R Code"),
          icon = tool_icon("code-blocks"),
          show_request = FALSE,
          open = FALSE
        )
      )
    ))
  }
  
  captured_plots <- check_for_plots(result)

  tool_value <- if (!is.null(captured_plots)) {
    lapply(captured_plots, function(plot_file) {
      ellmer::content_image_file(plot_file)
    })
  } else if (!is.null(result)) {
    paste0(utils::capture.output(print(result)), collapse = "\n")
  } else {
    "Code executed successfully."
  }

  if (is.character(tool_value)) {
    if (length(messages) > 0) {
      tool_value <- paste0(tool_value, "\n\nMessages:\n", paste(messages, collapse = "\n"))
    }

    if (length(warnings) > 0) {
      tool_value <- paste0(tool_value, "\n\nWarnings:\n", paste(warnings, collapse = "\n"))
    }
  }

  display_content <- create_run_r_code_display(
    code,
    result,
    messages,
    warnings,
    captured_plots
  )

  ellmer::ContentToolResult(
    value = tool_value,
    extra = list(
      code = code,
      display = display_content
    )
  )
}

check_for_plots <- function(result) {
  plots <- list()
  
  if (inherits(result, "ggplot")) {
    plots <- list(result)
  } else if (is.list(result)) {
    plots <- Filter(function(x) {
      inherits(x, "ggplot") || 
        inherits(x, "recordedplot") ||
        inherits(x, "trellis")
    }, result)
  }
  
  if (length(plots) == 0) {
    return(NULL)
  }
  
  plot_files <- lapply(seq_along(plots), function(i) {
    plot <- plots[[i]]
    temp_file <- tempfile(fileext = ".png")
    
    if (inherits(plot, "ggplot")) {
      ggplot2::ggsave(temp_file, plot, width = 8, height = 6, dpi = 150)
    } else if (inherits(plot, "trellis")) {
      grDevices::png(temp_file, width = 800, height = 600)
      print(plot)
      grDevices::dev.off()
    } else if (inherits(plot, "recordedplot")) {
      grDevices::png(temp_file, width = 800, height = 600)
      grDevices::replayPlot(plot)
      grDevices::dev.off()
    }
    
    temp_file
  })
  
  plot_files
}

create_run_r_code_display <- function(code, result, messages, warnings, plot_files) {
  has_plots <- !is.null(plot_files) && length(plot_files) > 0

  if (has_plots) {
    html_parts <- list(
      htmltools::tags$pre(
        htmltools::tags$code(class = "language-r", code)
      )
    )

    for (i in seq_along(plot_files)) {
      img_data <- base64enc::base64encode(plot_files[[i]])
      html_parts <- c(html_parts, list(
        htmltools::tags$img(
          src = sprintf("data:image/png;base64,%s", img_data),
          style = "max-width: 100%; height: auto; display: block; margin: 10px 0;"
        )
      ))
    }

    return(list(
      html = htmltools::tagList(html_parts),
      title = htmltools::HTML("Run R code"),
      icon = tool_icon("code-blocks"),
      show_request = FALSE,
      open = TRUE
    ))
  }

  output_lines <- character()

  if (!is.null(result)) {
    result_text <- paste0(utils::capture.output(print(result)), collapse = "\n")
    if (nchar(result_text) > 0) {
      result_lines <- strsplit(result_text, "\n", fixed = TRUE)[[1]]
      output_lines <- c(output_lines, paste0("#> ", result_lines))
    }
  }

  if (length(messages) > 0) {
    message_lines <- strsplit(paste(messages, collapse = "\n"), "\n", fixed = TRUE)[[1]]
    output_lines <- c(output_lines, paste0("#> ", message_lines))
  }

  if (length(warnings) > 0) {
    warning_lines <- strsplit(paste(warnings, collapse = "\n"), "\n", fixed = TRUE)[[1]]
    output_lines <- c(output_lines, paste0("#> Warning: ", warning_lines[1]))
    if (length(warning_lines) > 1) {
      output_lines <- c(output_lines, paste0("#> ", warning_lines[-1]))
    }
  }

  formatted_code <- if (length(output_lines) > 0) {
    sprintf("```r\n%s\n%s\n```", code, paste(output_lines, collapse = "\n"))
  } else {
    sprintf("```r\n%s\n```", code)
  }

  list(
    markdown = formatted_code,
    title = htmltools::HTML("Run R code"),
    icon = tool_icon("code-blocks"),
    show_request = FALSE,
    open = TRUE
  )
}

tool_run_r_code <- function() {
  ellmer::tool(
    run_r_code_impl,
    name = "run_r_code",
    description = paste(
      "Execute R code in the global environment and return the result.",
      "This tool evaluates R expressions and captures the output, messages, warnings, and errors.",
      "By default, the code runs in a fresh clone of the global environment, so assignments will not persist.",
      "",
      "Usage guidelines:",
      "- Use this for, data analysis, loading packages, transformations, and generating plots",
      "- Prefer btw_tool_docs_* tools for reading documentation",
      "- Prefer btw_tool_env_* tools for exploring objects in the environment",
      "- Prefer btw_tool_session_* tools for checking installed packages",
      "",
      "Persistence:",
      "- Only set persist to true if the user explicitly requests it AND you have written the code to a file first (for reproducibility)",
      "- When persist = true, assignments will persist in the user's actual environment"
    ),
    arguments = list(
      code = ellmer::type_string(
        "The R code to execute. Can be a single expression or multiple statements."
      ),
      persist = ellmer::type_boolean(
        "Whether to run code in the user's actual global environment (true) or a clone (false). Default is false. Only use true if the user explicitly requests it AND you have written the code to a file first for reproducibility.",
        required = FALSE
      ),
      `_intent` = ellmer::type_string(
        "Brief description of why you're running this code",
        required = FALSE
      )
    ),
    convert = FALSE,
    annotations = ellmer::tool_annotations(
      icon = tool_icon("code-blocks")
    )
  )
}
