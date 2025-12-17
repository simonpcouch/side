install_thinking_stream_hook <- function() {
  if (isTRUE(getOption("side.thinking_hook_installed"))) {
    return(invisible(NULL))
  }

  stream_text <- ellmer:::stream_text

  patched_anthropic <- function(provider, event) {
    if (event$type == "content_block_start") {
      is_thinking <- identical(event$content_block$type, "thinking")
      options(side.current_block_is_thinking = is_thinking)
      return(NULL)
    }

    if (event$type == "content_block_stop") {
      if (isTRUE(getOption("side.current_block_is_thinking"))) {
        done_callback <- getOption("side.thinking_done_callback")
        if (is.function(done_callback)) {
          done_callback()
        }
      }
      options(side.current_block_is_thinking = NULL)
      return(NULL)
    }

    if (event$type == "content_block_delta") {
      if (identical(event$delta$type, "thinking_delta")) {
        callback <- getOption("side.thinking_stream_callback")
        if (is.function(callback)) {
          callback(event$delta$thinking)
        }
        return(NULL)
      } else if (identical(event$delta$type, "text_delta")) {
        return(event$delta$text)
      }
    }
    NULL
  }

  patched_openai <- function(provider, event) {
    if (event$type == "response.output_text.delta") {
      return(event$delta)
    } else if (event$type == "response.reasoning_summary_text.delta") {
      callback <- getOption("side.thinking_stream_callback")
      if (is.function(callback)) {
        callback(event$delta)
      }
      return(NULL)
    } else if (event$type == "response.reasoning_summary_text.done") {
      done_callback <- getOption("side.thinking_done_callback")
      if (is.function(done_callback)) {
        done_callback()
      }
      return(NULL)
    }
    NULL
  }

  patched_gemini <- function(provider, event) {
    parts <- event$candidates[[1]]$content$parts
    if (is.null(parts) || length(parts) == 0) {
      return(NULL)
    }

    callback <- getOption("side.thinking_stream_callback")
    text_parts <- character()
    has_thinking <- FALSE

    for (part in parts) {
      if (isTRUE(part$thought) && !is.null(part$text)) {
        has_thinking <- TRUE
        if (is.function(callback)) {
          callback(part$text)
        }
      } else if (!is.null(part$text)) {
        text_parts <- c(text_parts, part$text)
      }
    }

    was_thinking <- isTRUE(getOption("side.gemini_was_thinking"))
    if (was_thinking && !has_thinking) {
      done_callback <- getOption("side.thinking_done_callback")
      if (is.function(done_callback)) {
        done_callback()
      }
    }
    options(side.gemini_was_thinking = has_thinking)

    if (length(text_parts) > 0) {
      return(paste(text_parts, collapse = ""))
    }
    NULL
  }

  patched_gemini_value_turn <- function(provider, result, has_type = FALSE) {
    message <- result$candidates[[1]]$content

    contents <- lapply(message$parts, function(content) {
      if (isTRUE(content$thought) && !is.null(content$text)) {
        ellmer::ContentThinking(thinking = content$text)
      } else if (!is.null(content$text)) {
        if (has_type) {
          ellmer::ContentJson(string = content$text)
        } else {
          ellmer::ContentText(content$text)
        }
      } else if (!is.null(content$functionCall)) {
        extra <- if (!is.null(content$thoughtSignature)) {
          list(thoughtSignature = content$thoughtSignature)
        } else {
          list()
        }
        ellmer::ContentToolRequest(
          content$functionCall$name,
          content$functionCall$name,
          content$functionCall$args,
          extra = extra
        )
      } else if (!is.null(content$inlineData)) {
        ellmer::ContentImageInline(
          type = content$inlineData$mimeType,
          data = content$inlineData$data
        )
      } else {
        NULL
      }
    })
    contents <- Filter(Negate(is.null), contents)
    tokens <- ellmer:::value_tokens(provider, result)
    cost <- ellmer:::get_token_cost(provider, tokens)
    ellmer::AssistantTurn(
      contents,
      json = result,
      tokens = unlist(tokens),
      cost = cost
    )
  }

  ProviderAnthropic <- ellmer:::ProviderAnthropic
  ProviderOpenAI <- ellmer:::ProviderOpenAI
  ProviderGoogleGemini <- ellmer:::ProviderGoogleGemini
  value_turn <- ellmer:::value_turn

  S7::method(stream_text, ProviderAnthropic) <- patched_anthropic
  S7::method(stream_text, ProviderOpenAI) <- patched_openai
  S7::method(stream_text, ProviderGoogleGemini) <- patched_gemini
  S7::method(value_turn, ProviderGoogleGemini) <- patched_gemini_value_turn

  options(side.thinking_hook_installed = TRUE)

  invisible(NULL)
}

set_thinking_stream_callback <- function(context) {
  if (is.null(context)) {
    options(side.thinking_stream_callback = NULL)
    options(side.thinking_done_callback = NULL)
    return(invisible(NULL))
  }

  text_callback <- function(text) {
    thinking_context_emit(context, text, done = FALSE)
  }

  done_callback <- function() {
    if (!is.null(context$id)) {
      thinking_context_emit(context, "", done = TRUE)
      context$id <- NULL
    }
  }

  options(side.thinking_stream_callback = text_callback)
  options(side.thinking_done_callback = done_callback)
  invisible(NULL)
}

clear_thinking_stream_callback <- function() {
  options(side.thinking_stream_callback = NULL)
  options(side.thinking_done_callback = NULL)
  options(side.current_block_is_thinking = NULL)
  options(side.gemini_was_thinking = NULL)
  invisible(NULL)
}

thinking_next_assistant_index <- function(client) {
  turns <- client$get_turns()
  assistant_count <- sum(vapply(
    turns,
    function(turn) turn@role == "assistant",
    logical(1)
  ))
  assistant_count + 1
}

thinking_context_new <- function(session, assistant_index) {
  rlang::env(
    session = session,
    id = NULL,
    assistant_index = assistant_index
  )
}

thinking_context_emit <- function(context, text, done = FALSE) {
  if (is.null(context$session)) {
    return(invisible(NULL))
  }

  text <- paste0(text, collapse = "")

  if (is.null(context$id)) {
    if (done && !nzchar(text)) {
      return(invisible(NULL))
    }

    context$id <- paste0(
      "think-live-",
      format(Sys.time(), "%H%M%S%OS3"),
      "-",
      sample.int(1e6, 1)
    )
  }

  context$session$sendCustomMessage(
    "side-thinking-stream",
    list(
      id = context$id,
      text = text,
      done = done,
      mode = "live",
      order = context$assistant_index
    )
  )

  invisible(NULL)
}

thinking_context_finalize <- function(context) {
  if (!is.null(context$session) && !is.null(context$id)) {
    thinking_context_emit(context, "", done = TRUE)
  }

  invisible(NULL)
}

thinking_replay_history <- function(client, session) {
  if (is.null(session)) {
    return(invisible(NULL))
  }

  turns <- client$get_turns()
  assistant_index <- 0

  for (turn in turns) {
    if (turn@role != "assistant") {
      next
    }
    assistant_index <- assistant_index + 1

    for (content in turn@contents) {
      if (!S7::S7_inherits(content, ellmer::ContentThinking)) {
        next
      }

      thinking_text <- content@thinking
      if (!nzchar(thinking_text)) {
        next
      }

      id <- paste0(
        "think-history-",
        format(Sys.time(), "%H%M%S%OS3"),
        "-",
        sample.int(1e6, 1)
      )

      session$sendCustomMessage(
        "side-thinking-stream",
        list(
          id = id,
          text = thinking_text,
          done = TRUE,
          mode = "history",
          order = assistant_index
        )
      )
    }
  }

  invisible(NULL)
}

toggle_thinking <- function(client, enable = TRUE) {
  provider <- client$get_provider()
  cls <- sub("^.*::", "", class(provider)[1])
  UseMethod("toggle_thinking", structure(list(), class = cls))
}

#' @export
toggle_thinking.ProviderAnthropic <- function(client, enable = TRUE) {
  provider <- client$get_provider()

  if (enable && !supports_thinking(provider)) {
    cli::cli_warn("This model may not support thinking tokens.")
  }

  if (enable) {
    provider@params$reasoning_tokens <- 1024
  } else {
    provider@params$reasoning_tokens <- NULL
  }

  set_provider(client, provider)
  invisible(client)
}

#' @export
toggle_thinking.ProviderOpenAI <- function(client, enable = TRUE) {
  provider <- client$get_provider()

  if (enable && !supports_thinking(provider)) {
    cli::cli_warn(
      "This model does not support thinking tokens. Use an o-series or gpt-5+ model."
    )
    return(invisible(client))
  }

  if (enable) {
    provider@params$reasoning_effort <- "medium"
  } else {
    model <- provider@model
    if (
      grepl("^gpt-5\\.[2-9]|^gpt-5\\.1[0-9]|^gpt-[6-9]|^gpt-[0-9]{2,}", model)
    ) {
      provider@params$reasoning_effort <- "none"
    } else if (grepl("^gpt-5", model)) {
      provider@params$reasoning_effort <- "low"
    } else {
      provider@params$reasoning_effort <- NULL
    }
  }

  set_provider(client, provider)
  invisible(client)
}

#' @export
toggle_thinking.ProviderGoogleGemini <- function(client, enable = TRUE) {
  provider <- client$get_provider()

  if (enable && !supports_thinking(provider)) {
    cli::cli_warn(
      "This model may not support thinking tokens. Use gemini-2.5+ or later."
    )
  }

  if (enable) {
    provider@params$reasoning_tokens <- 1024
  } else {
    provider@params$reasoning_tokens <- NULL
  }

  set_provider(client, provider)
  invisible(client)
}

#' @export
toggle_thinking.default <- function(client, enable = TRUE) {
  provider <- client$get_provider()

  if (enable && !supports_thinking(provider)) {
    cli::cli_warn("Thinking is not supported for this provider.")
    return(invisible(client))
  }

  invisible(client)
}

supports_thinking <- function(provider) {
  cls <- sub("^.*::", "", class(provider)[1])
  UseMethod("supports_thinking", structure(list(), class = cls))
}

#' @export
supports_thinking.ProviderAnthropic <- function(provider) {
  model <- provider@model
  grepl("claude-[a-z]+-([4-9]|[0-9]{2,})", model, ignore.case = TRUE)
}

#' @export
supports_thinking.ProviderOpenAI <- function(provider) {
  model <- provider@model
  is_o_series <- grepl("^o[0-9]", model)
  is_gpt5_plus <- grepl("^gpt-([5-9]|[0-9]{2,})", model)
  is_o_series || is_gpt5_plus
}

#' @export
supports_thinking.ProviderGoogleGemini <- function(provider) {
  model <- provider@model
  if (grepl("^gemini-([3-9]|[0-9]{2,})", model)) {
    return(TRUE)
  }
  if (grepl("^gemini-2\\.([5-9]|[0-9]{2,})", model)) {
    return(TRUE)
  }
  FALSE
}

#' @export
supports_thinking.default <- function(provider) {
  FALSE
}

set_provider <- function(client, provider) {
  private <- client$.__enclos_env__$private
  private$provider <- provider
  invisible(client)
}

thinking_is_enabled <- function(client) {
  provider <- client$get_provider()
  cls <- sub("^.*::", "", class(provider)[1])

  if (cls == "ProviderAnthropic") {
    return(!is.null(provider@params$reasoning_tokens))
  } else if (cls == "ProviderOpenAI") {
    effort <- provider@params$reasoning_effort
    return(!is.null(effort) && effort != "none" && effort != "low")
  } else if (cls == "ProviderGoogleGemini") {
    return(!is.null(provider@params$reasoning_tokens))
  }

  FALSE
}

client_supports_thinking <- function(client) {
  provider <- client$get_provider()
  supports_thinking(provider)
}
