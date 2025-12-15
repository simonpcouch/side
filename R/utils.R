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

  tryCatch(
    {
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
    },
    error = function(e) {
      "Invalid chat file"
    }
  )
}

extract_first_text <- function(turn) {
  text_contents <- Filter(
    function(c) {
      inherits(c, "ContentText") || inherits(c, "ellmer::ContentText")
    },
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

save_chat <- function(
  client,
  path = getwd(),
  persist = NULL,
  existing_file = NULL
) {
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

  tryCatch(
    {
      fresh_client$set_turns(old_client$get_turns())
      if (thinking_is_enabled(old_client)) {
        toggle_thinking(fresh_client, TRUE)
      }
    },
    error = function(e) {
      cli::cli_inform(c(
        "!" = "Chat from previous ellmer version failed to load.",
        "i" = "Starting a new chat."
      ))
    }
  )

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
# a stream completes successfully. When we interrupt mid-stream,
# we need to ensure that user/assistant turns alternate back-and-forth, and that
# all tool requests have matching tool results.
#
# For the purposes of this app, interrupts either occur 1) during the tool
# calling loop or 2) not.
# 1) When during the tool calling loop, just confirm that tool calling loops
# appear complete by patching requests that don't have matching results with
# a text content.
# 2) When not during tool calling, process the streamed text content and
# let that form the assistant turn.
patch_interrupted_chat <- function(
  client,
  streamed_content = NULL,
  user_input = NULL
) {
  # saveRDS(
  #   list(client = client, streamed_content = streamed_content, user_input = user_input),
  #   "/Users/simoncouch/.config/side/before_patching.rds"
  # )
  request_ids <- character()
  for (turn in client$get_turns()) {
    .res <- lapply(turn@contents, function(c) {
      if (S7::S7_inherits(c, ellmer::ContentToolRequest)) {
        request_ids <<- c(request_ids, c@id)
      }
    })
  }

  result_ids <- character()
  for (turn in client$get_turns()) {
    .res <- lapply(turn@contents, function(c) {
      if (S7::S7_inherits(c, ellmer::ContentToolResult)) {
        result_ids <<- c(result_ids, c@request@id)
      }
    })
  }

  requests_without_matches <- request_ids[!request_ids %in% result_ids]

  old_turns <- client$get_turns()
  new_turns <- list()
  for (turn in old_turns) {
    turn@contents <- lapply(turn@contents, function(c) {
      if (
        S7::S7_inherits(c, ellmer::ContentToolRequest) &&
          c@id %in% requests_without_matches
      ) {
        return(ellmer::ContentText(
          paste0("_Tool call to `", c@name, "` interrupted._")
        ))
      }

      c
    })

    new_turns <- c(new_turns, turn)
  }

  # If there are requests without matches, the interruption happended during
  # the tool calling loop. In that case, just patch the tool call turns and
  # don't worry about updating from other streamed content--ellmer already
  # had a chance to form complete turns up to the penultimate one.
  if (length(requests_without_matches) > 0) {
    client$set_turns(new_turns)
    return(client)
  }

  if (!is.null(streamed_content)) {
    text_content <- vapply(
      streamed_content,
      function(c) S7::S7_inherits(c, ellmer::ContentText),
      logical(1)
    )
    text_content <- paste0(
      vapply(streamed_content[text_content], function(c) c@text, character(1)),
      collapse = ""
    )
    text_content <- paste0(text_content, "...\n\n_Streaming interrupted._")

    if (length(new_turns) == 0) {
      last_turn_is_assistant <- TRUE
    } else {
      last_turn_is_assistant <- new_turns[[length(new_turns)]]@role ==
        "assistant"
    }

    if (last_turn_is_assistant) {
      new_turns <- c(
        new_turns,
        list(
          ellmer::Turn("user", list(ellmer::ContentText(user_input))),
          ellmer::Turn("assistant", list(ellmer::ContentText(text_content)))
        )
      )
    } else {
      # The most recent turn is a user turn, so update its contents with
      # the new user input
      last_user_turn <- new_turns[[length(new_turns)]]
      last_user_turn@contents <- c(
        last_user_turn@contents,
        ellmer::ContentText(user_input)
      )
      new_turns[[length(new_turns)]] <- last_user_turn

      new_turns <- c(
        new_turns,
        list(ellmer::Turn("assistant", list(ellmer::ContentText(text_content))))
      )
    }
  }

  client$set_turns(new_turns)
  client
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

interactive <- NULL
