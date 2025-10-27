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

    if (length(user_turns) == 0) {
      first_words <- "New conversation"
    } else {
      first_turn <- user_turns[[1]]
      text_contents <- Filter(
        function(c) inherits(c, "ContentText") || inherits(c, "ellmer::ContentText"),
        first_turn@contents
      )

      text <- NULL
      if (length(text_contents) > 0 && !is.null(text_contents[[1]]@text)) {
        text <- text_contents[[1]]@text
      }

      if (is.null(text) || nchar(trimws(text)) == 0) {
        first_words <- "New conversation"
      } else {
        words <- strsplit(text, "\\s+")[[1]]
        first_words <- paste(head(words, 4), collapse = " ")

        if (nchar(first_words) > 40) {
          first_words <- paste0(substr(first_words, 1, 37), "...")
        }
      }
    }

    mtime <- file.info(chat_file)$mtime
    date_str <- format(mtime, "%d-%m-%Y %H:%M")

    paste0(first_words, " (", date_str, ")")
  }, error = function(e) {
    "Invalid chat file"
  })
}

sanitize_filename <- function(text) {
  words <- strsplit(text, "\\s+")[[1]]
  first_words <- paste(head(words, 4), collapse = " ")

  sanitized <- tolower(first_words)
  sanitized <- gsub("[^a-z0-9]+", "_", sanitized)
  sanitized <- gsub("^_+|_+$", "", sanitized)

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  paste0(sanitized, "__", timestamp, ".rds")
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

  if (length(user_turns) == 0) {
    filename <- paste0("new_conversation__", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
  } else {
    first_turn <- user_turns[[1]]

    text_contents <- Filter(
      function(c) inherits(c, "ContentText") || inherits(c, "ellmer::ContentText"),
      first_turn@contents
    )

    text <- NULL
    if (length(text_contents) > 0 && !is.null(text_contents[[1]]@text)) {
      text <- text_contents[[1]]@text
    }

    if (is.null(text) || nchar(trimws(text)) == 0) {
      filename <- paste0("new_conversation__", format(Sys.time(), "%Y%m%d_%H%M%S"), ".rds")
    } else {
      filename <- sanitize_filename(text)
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

  tryCatch({
    old_client <- readRDS(chat_file)

    turns <- old_client$get_turns()
    system_prompt <- old_client$get_system_prompt()

    fresh_client$set_turns(turns)
    if (!is.null(system_prompt)) {
      fresh_client$set_system_prompt(system_prompt)
    }

    fresh_client
  }, error = function(e) {
    cli::cli_abort(
      c(
        "Failed to load chat from {.path {chat_file}}",
        "i" = "Error: {conditionMessage(e)}"
      )
    )
  })
}

delete_oldest_chats <- function(path = getwd(), persist = NULL) {
  if (is.null(persist)) {
    persist <- should_persist()
  }

  chat_dir <- get_chat_dir(path, persist = persist)

  if (!dir.exists(chat_dir)) {
    return(invisible(NULL))
  }

  files <- get_chat_files(path, persist = persist)

  if (length(files) > 3) {
    to_delete <- files[4:length(files)]
    for (f in to_delete) {
      unlink(f)
    }
  }

  if (!persist) {
    return(invisible(NULL))
  }

  base_dir <- if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("APPDATA"), "side", "chats")
  } else {
    file.path(Sys.getenv("HOME"), ".config", "side", "chats")
  }

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
    for (f in to_delete) {
      unlink(f)
    }
  }

  invisible(NULL)
}



# interrupt handling ----------------------------------------------------------

clean_incomplete_tool_requests <- function(client) {
  turns <- client$get_turns()
  if (length(turns) == 0) {
    return(invisible(client))
  }

  last_turn <- turns[[length(turns)]]
  if (last_turn@role != "assistant") {
    return(invisible(client))
  }

  contents <- last_turn@contents
  requests <- Filter(function(c) S7::S7_inherits(c, ellmer::ContentToolRequest), contents)
  results <- Filter(function(c) S7::S7_inherits(c, ellmer::ContentToolResult), contents)

  if (length(requests) == 0) {
    return(invisible(client))
  }

  result_ids <- character(0)
  if (length(results) > 0) {
    result_ids <- vapply(results, function(r) {
      if (!is.null(r@request) && !is.null(r@request@id)) {
        r@request@id
      } else {
        NA_character_
      }
    }, character(1))
    result_ids <- result_ids[!is.na(result_ids)]
  }

  incomplete_ids <- character(0)
  for (req in requests) {
    if (!is.null(req@id) && !(req@id %in% result_ids)) {
      incomplete_ids <- c(incomplete_ids, req@id)
    }
  }

  if (length(incomplete_ids) == 0) {
    return(invisible(client))
  }

  new_contents <- Filter(
    function(c) {
      if (S7::S7_inherits(c, ellmer::ContentToolRequest)) {
        !is.null(c@id) && !(c@id %in% incomplete_ids)
      } else {
        TRUE
      }
    },
    contents
  )

  last_turn@contents <- new_contents
  turns[[length(turns)]] <- last_turn
  client$set_turns(turns)

  invisible(client)
}


# ad-hoc check functions ------------------------------------------------------
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
