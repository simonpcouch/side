the <- rlang::new_environment()

stash_last_kick <- function(client) {
  the[[".last_kick"]] <- client
  invisible(NULL)
}

get_last_kick <- function() {
  if (rlang::env_has(the, ".last_kick")) {
    return(rlang::env_get(the, ".last_kick"))
  }
  NULL
}

tool_icon <- local({
  icons <- list()
  function(name) {
    if (!is.null(icons[[name]])) {
      return(icons[[name]])
    }

    icon <- htmltools::HTML(readLines(
      system.file("icons", paste0(name, ".svg"), package = "side"),
      warn = FALSE
    ))
    icons[[name]] <<- icon
    return(icon)
  }
})


# chat persistence helpers ----------------------------------------------------

should_persist <- function() {
  interactive() || identical(Sys.getenv("NOT_CRAN"), "true")
}

get_chat_dir <- function(path = getwd(), persist = NULL) {
  if (is.null(persist)) {
    persist <- should_persist()
  }

  if (!persist) {
    return(file.path(tempdir(), "side_chats"))
  }

  dir_basename <- basename(normalizePath(path, mustWork = FALSE))

  if (.Platform$OS.type == "windows") {
    base_dir <- file.path(Sys.getenv("APPDATA"), "side", "chats")
  } else {
    base_dir <- file.path(Sys.getenv("HOME"), ".config", "side", "chats")
  }

  file.path(base_dir, dir_basename)
}

get_chat_files <- function(path = getwd(), persist = NULL) {
  chat_dir <- get_chat_dir(path, persist = persist)

  if (!dir.exists(chat_dir)) {
    return(character(0))
  }

  files <- list.files(chat_dir, pattern = "\\.rds$", full.names = TRUE)

  if (length(files) == 0) {
    return(character(0))
  }

  info <- file.info(files)
  files[order(info$mtime, decreasing = TRUE)]
}

get_chat_label <- function(chat_file) {
  if (!file.exists(chat_file)) {
    return("Unknown chat")
  }

  tryCatch({
    client <- readRDS(chat_file)
    turns <- client$get_turns()
    user_turns <- Filter(function(turn) turn@role == "user", turns)

    first_words <- if (length(user_turns) == 0) {
      "New conversation"
    } else {
      text <- extract_first_text(user_turns[[1]])
      if (is.null(text) || nchar(trimws(text)) == 0) {
        "New conversation"
      } else {
        truncate_text(text)
      }
    }

    mtime <- file.info(chat_file)$mtime
    paste0(first_words, " (", format(mtime, "%d-%m-%Y %H:%M"), ")")
  }, error = function(e) {
    "Invalid chat file"
  })
}

extract_first_text <- function(turn) {
  text_contents <- Filter(
    function(c) inherits(c, "ContentText") || inherits(c, "ellmer::ContentText"),
    turn@contents
  )
  if (length(text_contents) > 0 && !is.null(text_contents[[1]]@text)) {
    text_contents[[1]]@text
  } else {
    NULL
  }
}

truncate_text <- function(text, max_words = 4, max_chars = 40) {
  words <- strsplit(text, "\\s+")[[1]]
  result <- paste(head(words, max_words), collapse = " ")
  if (nchar(result) > max_chars) {
    paste0(substr(result, 1, max_chars - 3), "...")
  } else {
    result
  }
}

sanitize_filename <- function(text) {
  sanitized <- paste(head(strsplit(text, "\\s+")[[1]], 4), collapse = " ")
  sanitized <- gsub("[^a-z0-9]+", "_", tolower(sanitized))
  sanitized <- gsub("^_+|_+$", "", sanitized)
  paste0(sanitized, "__", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
}

save_chat <- function(client, path = getwd(), persist = NULL, existing_file = NULL) {
  turns <- client$get_turns()
  if (length(turns) == 0) {
    return(invisible(NULL))
  }

  if (!is.null(existing_file) && file.exists(existing_file)) {
    saveRDS(client, existing_file)
    return(invisible(existing_file))
  }

  chat_dir <- get_chat_dir(path, persist = persist)
  if (!dir.exists(chat_dir)) {
    dir.create(chat_dir, recursive = TRUE, showWarnings = FALSE)
  }

  user_turns <- Filter(function(turn) turn@role == "user", turns)

  filename <- if (length(user_turns) == 0) {
    paste0("new_conversation__", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
  } else {
    text <- extract_first_text(user_turns[[1]])
    if (is.null(text) || nchar(trimws(text)) == 0) {
      paste0("new_conversation__", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
    } else {
      sanitize_filename(text)
    }
  }

  filepath <- file.path(chat_dir, filename)
  saveRDS(client, filepath)
  invisible(filepath)
}

load_chat <- function(chat_file, fresh_client) {
  if (!file.exists(chat_file)) {
    cli::cli_abort("Chat file {.path {chat_file}} does not exist.")
  }

  old_client <- readRDS(chat_file)
  fresh_client$set_turns(old_client$get_turns())

  fresh_client
}

delete_oldest_chats <- function(path = getwd(), persist = NULL) {
  if (is.null(persist)) {
    persist <- should_persist()
  }

  files <- get_chat_files(path, persist = persist)
  if (length(files) > 3) {
    to_delete <- files[4:length(files)]
    unlink(to_delete)
  }

  if (!persist) {
    return(invisible(NULL))
  }

  base_dir <- get_config_dir("chats")
  if (!dir.exists(base_dir)) {
    return(invisible(NULL))
  }

  all_dirs <- list.dirs(base_dir, recursive = FALSE, full.names = TRUE)
  all_files <- unlist(lapply(all_dirs, function(d) {
    list.files(d, pattern = "\\.rds$", full.names = TRUE)
  }))

  if (length(all_files) > 15) {
    info <- file.info(all_files)
    all_files_sorted <- all_files[order(info$mtime, decreasing = TRUE)]
    to_delete <- all_files_sorted[16:length(all_files_sorted)]
    unlink(to_delete)
  }

  invisible(NULL)
}

get_config_dir <- function(subdir) {
  base <- if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("APPDATA"), "side")
  } else {
    file.path(Sys.getenv("HOME"), ".config", "side")
  }
  file.path(base, subdir)
}

# When a user interrupts a streaming response, ellmer's Chat is left in an
# inconsistent state. Normally, ellmer only adds turns to the Chat history after
# a stream completes successfully. When we interrupt mid-stream:
#
# 1. The user Turn is never added (ellmer was still processing)
# 2. The assistant Turn is never created (stream didn't complete)
# 3. Any partial content shown to the user is lost
#
# This creates two problems:
# - The Chat history is missing the interrupted exchange
# - LLM APIs require tool_use to have corresponding tool_result, but interrupted
#   tool requests may lack results
#
# This function patches the Chat to be in a valid, continuable state by:
# - Reconstructing the user Turn from the original input
# - Building an assistant Turn from all content that was streamed and shown
# - Adding synthetic tool_result for any incomplete tool_request
# - Properly structuring turns to match ellmer's conversation model:
#   * Plain text responses: single assistant turn
#   * Tool requests without results: assistant turn with requests + synthetic results
#   * Tool requests with results: assistant turn (requests only) + separate user turn (results)
# - Ensuring conversations can continue naturally after interrupt
patch_interrupted_chat <- function(client, streamed_content, user_input) {
  initial_user_turn <- ellmer::Turn(
    role = "user",
    contents = list(ellmer::ContentText(user_input))
  )

  assistant_contents <- list()
  text_chunks <- character(0)

  for (content in streamed_content) {
    if (is.character(content)) {
      text_chunks <- c(text_chunks, content)
    } else if (S7::S7_inherits(content, ellmer::ContentText)) {
      text_chunks <- c(text_chunks, content@text)
    } else if (S7::S7_inherits(content, ellmer::Content)) {
      if (length(text_chunks) > 0) {
        assistant_contents <- c(
          assistant_contents,
          list(ellmer::ContentText(paste(text_chunks, collapse = "")))
        )
        text_chunks <- character(0)
      }
      assistant_contents <- c(assistant_contents, list(content))
    }
  }

  if (length(text_chunks) > 0) {
    assistant_contents <- c(
      assistant_contents,
      list(ellmer::ContentText(paste(text_chunks, collapse = "")))
    )
  }

  tool_requests <- Filter(
    function(c) S7::S7_inherits(c, ellmer::ContentToolRequest),
    assistant_contents
  )
  tool_results <- Filter(
    function(c) S7::S7_inherits(c, ellmer::ContentToolResult),
    assistant_contents
  )

  result_request_ids <- character(0)
  if (length(tool_results) > 0) {
    result_request_ids <- vapply(tool_results, function(r) {
      if (!is.null(r@request) && !is.null(r@request@id)) {
        r@request@id
      } else {
        NA_character_
      }
    }, character(1))
    result_request_ids <- result_request_ids[!is.na(result_request_ids)]
  }

  incomplete_requests <- Filter(function(req) {
    !is.null(req@id) && !(req@id %in% result_request_ids)
  }, tool_requests)

  for (req in incomplete_requests) {
    synthetic_result <- ellmer::ContentToolResult(
      value = "Tool execution was interrupted by user.",
      request = req
    )
    tool_results <- c(tool_results, list(synthetic_result))
    assistant_contents <- c(assistant_contents, list(synthetic_result))
  }

  assistant_contents_without_results <- Filter(
    function(c) !S7::S7_inherits(c, ellmer::ContentToolResult),
    assistant_contents
  )

  has_tool_requests <- length(tool_requests) > 0
  has_tool_results <- length(tool_results) > 0

  if (!has_tool_requests) {
    last_is_text <- if (length(assistant_contents) > 0) {
      S7::S7_inherits(assistant_contents[[length(assistant_contents)]], ellmer::ContentText)
    } else {
      FALSE
    }

    if (!last_is_text) {
      assistant_contents <- c(
        assistant_contents,
        list(ellmer::ContentText("Acknowledged."))
      )
    }

    assistant_turn <- ellmer::Turn(
      role = "assistant",
      contents = assistant_contents
    )

    client$add_turn(initial_user_turn, assistant_turn)
  } else if (has_tool_results) {
    assistant_turn <- ellmer::Turn(
      role = "assistant",
      contents = assistant_contents_without_results
    )

    tool_result_turn <- ellmer::Turn(
      role = "user",
      contents = tool_results
    )

    client$add_turn(initial_user_turn, assistant_turn)

    turns <- client$get_turns()
    turns[[length(turns) + 1]] <- tool_result_turn
    client$set_turns(turns)
  } else {
    assistant_turn <- ellmer::Turn(
      role = "assistant",
      contents = assistant_contents
    )

    client$add_turn(initial_user_turn, assistant_turn)
  }

  invisible(client)
}

check_inherits <- function(
  x,
  class,
  x_arg = caller_arg(x),
  call = caller_env()
) {
  if (!inherits(x, class)) {
    cli::cli_abort(
      "{.arg {x_arg}} must be a {.cls {class}}, not {.obj_type_friendly {x}}.",
      call = call
    )
  }

  invisible(NULL)
}

strip_yaml_frontmatter <- function(lines) {
  if (length(lines) == 0 || lines[1] != "---") {
    return(lines)
  }
  
  yaml_end <- which(lines == "---")
  if (length(yaml_end) < 2) {
    return(lines)
  }
  
  content_start <- yaml_end[2] + 1
  if (content_start > length(lines)) {
    return(character(0))
  }
  
  lines[content_start:length(lines)]
}

interactive <- NULL
