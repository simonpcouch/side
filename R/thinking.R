thinking_instruction_line <- function() {
  "<noteFromSidekickApp>If you want to pause and consider your next steps, you can wrap a *very* short aside in `<think>...</think>` right at the start of your message. Close the tag before you continue replying. Avoid beginning your aside with 'The user...', and **crucially** avoid using the <think> tag for any use other than opening or closing that tag.</noteFromSidekickApp>"
}

thinking_prepend_instruction <- function(text) {
  instruction <- thinking_instruction_line()

  if (!nzchar(text)) {
    return(instruction)
  }

  paste(instruction, "", text, sep = "\n")
}

thinking_strip_instruction_text <- function(text) {
  instruction <- thinking_instruction_line()

  if (!isTRUE(startsWith(text, instruction))) {
    return(text)
  }

  remainder <- substr(text, nchar(instruction) + 1, nchar(text))
  remainder <- sub("^[\\r\\n]+", "", remainder)
  remainder
}

thinking_strip_instruction_turn <- function(turn) {
  if (is.null(turn) || turn@role != "user" || length(turn@contents) == 0) {
    return(turn)
  }

  for (i in seq_along(turn@contents)) {
    content <- turn@contents[[i]]
    if (S7::S7_inherits(content, ellmer::ContentText)) {
      new_text <- thinking_strip_instruction_text(content@text)
      if (!identical(new_text, content@text)) {
        turn@contents[[i]] <- ellmer::ContentText(new_text)
      }
      break
    }
  }

  turn
}

thinking_strip_native_content <- function(turn) {
  if (is.null(turn) || turn@role != "assistant") {
    return(turn)
  }

  if (
    !any(vapply(
      turn@contents,
      S7::S7_inherits,
      logical(1),
      ellmer::ContentThinking
    ))
  ) {
    return(turn)
  }

  turn@contents <- Filter(
    function(content) !S7::S7_inherits(content, ellmer::ContentThinking),
    turn@contents
  )
  turn
}

thinking_prune_client <- function(client) {
  turns <- client$get_turns(include_system_prompt = TRUE)
  if (length(turns) == 0) {
    return(invisible(client))
  }

  changed <- FALSE
  for (i in seq_along(turns)) {
    turn <- turns[[i]]
    if (turn@role == "user") {
      new_turn <- thinking_strip_instruction_turn(turn)
    } else if (turn@role == "assistant") {
      new_turn <- thinking_strip_native_content(turn)
    } else {
      new_turn <- turn
    }

    if (!identical(new_turn, turn)) {
      turns[[i]] <- new_turn
      changed <- TRUE
    }
  }

  if (changed) {
    client$set_turns(turns)
  }

  invisible(client)
}

ensure_thinking_tool_patch <- function() {
  if (isTRUE(getOption("side.ellmer_tool_patch", FALSE))) {
    return(invisible(NULL))
  }

  if (!requireNamespace("ellmer", quietly = TRUE)) {
    return(invisible(NULL))
  }

  ns <- asNamespace("ellmer")
  original <- get("tool_results_as_turn", envir = ns)

  patched <- function(results) {
    turn <- original(results)
    if (!isTRUE(getOption("side.thinking_enabled", FALSE))) {
      return(turn)
    }
    if (is.null(turn)) {
      return(turn)
    }

    instruction <- thinking_instruction_line()
    text_content <- ellmer::ContentText(instruction)
    turn@contents <- c(list(text_content), turn@contents)
    turn
  }

  assignInNamespace("tool_results_as_turn", patched, ns = "ellmer")
  options(side.ellmer_tool_patch = TRUE)
  invisible(NULL)
}

disable_provider_reasoning <- function(client) {
  provider <- client$get_provider()
  if (inherits(provider, "ProviderAnthropic")) {
    provider@params$reasoning_tokens <- NULL
    provider@params$reasoning_effort <- NULL
  } else if (inherits(provider, "ProviderOpenAI")) {
    provider@params$reasoning_effort <- NULL
  } else if (inherits(provider, "ProviderGoogleGemini")) {
    provider@params$reasoning_tokens <- NULL
  }

  private <- client$.__enclos_env__$private
  private$provider <- provider
  invisible(client)
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

thinking_context_new <- function(
  enabled,
  session,
  assistant_index,
  live = TRUE
) {
  rlang::env(
    enabled = isTRUE(enabled),
    session = session,
    id = NULL,
    buffer = "",
    in_tag = FALSE,
    assistant_index = assistant_index,
    live = live
  )
}

thinking_context_emit <- function(context, text, done = FALSE) {
  if (!context$enabled || is.null(context$session)) {
    return(invisible(NULL))
  }

  text <- paste0(text, collapse = "")

  if (is.null(context$id)) {
    if (done && !nzchar(text)) {
      return(invisible(NULL))
    }

    timestamp_ms <- as.integer(as.numeric(Sys.time()) * 1000)
    context$id <- paste0(
      if (context$live) "think-live" else "think-history",
      "-",
      timestamp_ms,
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
      mode = if (context$live) "live" else "history",
      order = context$assistant_index
    )
  )

  invisible(NULL)
}

thinking_context_process_text <- function(context, text) {
  if (!context$enabled) {
    return(text)
  }

  if (length(text) == 0 || all(is.na(text))) {
    return(character())
  }

  text <- paste0(text, collapse = "")

  if (!nzchar(text)) {
    return(character())
  }

  visible <- character()
  remainder <- text

  while (nzchar(remainder)) {
    if (!context$in_tag) {
      open <- regexpr("<think>", remainder, fixed = TRUE)
      if (open == -1) {
        visible <- c(visible, remainder)
        remainder <- ""
      } else {
        before <- substr(remainder, 1, open - 1)
        if (nzchar(before)) {
          visible <- c(visible, before)
        }
        remainder <- substr(
          remainder,
          open + nchar("<think>"),
          nchar(remainder)
        )
        context$in_tag <- TRUE
        thinking_context_emit(context, "", done = FALSE)
      }
    } else {
      close <- regexpr("</think>", remainder, fixed = TRUE)
      if (close == -1) {
        context$buffer <- paste0(context$buffer, remainder)
        thinking_context_emit(context, remainder, done = FALSE)
        remainder <- ""
      } else {
        chunk <- substr(remainder, 1, close - 1)
        if (nzchar(chunk)) {
          context$buffer <- paste0(context$buffer, chunk)
          thinking_context_emit(context, chunk, done = FALSE)
        }
        remainder <- substr(
          remainder,
          close + nchar("</think>"),
          nchar(remainder)
        )
        context$in_tag <- FALSE
        thinking_context_emit(context, "", done = TRUE)
      }
    }
  }

  visible
}

thinking_context_finalize <- function(context) {
  if (!context$enabled) {
    return(invisible(NULL))
  }

  if (isTRUE(context$in_tag)) {
    context$in_tag <- FALSE
  }

  if (!is.null(context$session) && !is.null(context$id)) {
    thinking_context_emit(context, "", done = TRUE)
  }

  invisible(NULL)
}

thinking_get_log <- function(client) {
  attr(client, "side_thinking_log") %||% list()
}

thinking_set_log <- function(client, log) {
  attr(client, "side_thinking_log") <- log
  client
}

thinking_record_log <- function(client, assistant_index, text) {
  if (!nzchar(text)) {
    return(invisible(client))
  }

  log <- thinking_get_log(client)
  log[[as.character(assistant_index)]] <- text
  thinking_set_log(client, log)
  invisible(client)
}

thinking_replay_history <- function(client, session) {
  if (is.null(session)) {
    return(invisible(NULL))
  }

  log <- thinking_get_log(client)
  if (length(log) == 0) {
    return(invisible(NULL))
  }

  for (name in names(log)) {
    text <- log[[name]]
    if (!nzchar(text)) {
      next
    }
    context <- thinking_context_new(
      TRUE,
      session,
      as.integer(name),
      live = FALSE
    )
    thinking_context_emit(context, text, done = TRUE)
  }

  invisible(NULL)
}
