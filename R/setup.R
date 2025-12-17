setup_client <- function(client = NULL, call = rlang::caller_env()) {
  if (!is.null(client)) {
    if (inherits(client, "Chat")) {
      return(client)
    } else if (is.character(client) && length(client) == 1) {
      if (length(gregexpr("/", client, fixed = TRUE)[[1]]) == 1) {
        return(ellmer::chat(client))
      }
    }

    cli::cli_abort(
      "{.arg client} must be a Chat object, not {.obj_type_friendly {client}}.",
      call = call
    )
  }

  if (!interactive()) {
    cli::cli_abort(
      c(
        "Setup requires an interactive R session.",
        i = "Set {.code options(side.client = ellmer::chat_*())} to continue.",
        i = "See {.help side::kick} for more information."
      ),
      call = NULL
    )
  }

  prompt_provider_selection()
}

prompt_provider_selection <- function() {
  providers <- list(
    list(
      name = "Anthropic (Claude Sonnet 4.5)",
      fn_name = "chat_anthropic",
      model = "claude-sonnet-4-5",
      create_client = function() {
        ellmer::chat_anthropic(model = "claude-sonnet-4-5")
      }
    ),
    list(
      name = "OpenAI (GPT 5.2)",
      fn_name = "chat_openai",
      model = "gpt-5.2",
      create_client = function() ellmer::chat_openai(model = "gpt-5.2")
    ),
    list(
      name = "Google Gemini (Gemini 3 Pro)",
      fn_name = "chat_google_gemini",
      model = "gemini-3-pro-preview",
      create_client = function() {
        ellmer::chat_google_gemini(model = "gemini-3-pro-preview")
      }
    ),
    list(
      name = "GitHub (GPT 4.1)",
      fn_name = "chat_github",
      model = "gpt-4.1",
      create_client = function() ellmer::chat_github(model = "gpt-4.1")
    )
  )

  for (i in seq_along(providers)) {
    providers[[i]]$available <- provider_available(providers[[i]]$create_client)
  }

  available_providers <- Filter(function(p) p$available, providers)

  if (length(available_providers) == 0) {
    cli::cli_abort(
      "Could not auto-discover an LLM provider, see {.help side::kick}.",
      call = NULL
    )
  }

  choices <- c(
    vapply(available_providers, function(p) p$name, character(1)),
    "Some other provider/model"
  )

  selection <- utils::menu(
    choices,
    title = "Which provider/model would you like to use with `side::kick`?"
  )

  if (selection == 0) {
    cli::cli_abort("Setup cancelled.", call = NULL)
  }

  if (selection == length(choices)) {
    cli::cli_abort(
      c(
        "Set the {.code side.client} option with
         {.code options(side.client = ellmer::chat_*())} to continue.",
        i = "See {.help side::kick} for more information."
      ),
      call = call2("side::kick()")
    )
  }

  selected_info <- available_providers[[selection]]
  client <- selected_info$create_client()

  options(side.client = client)

  prompt_persistence_selection(
    client,
    selected_info$fn_name,
    selected_info$model
  )

  client
}

prompt_persistence_selection <- function(client, fn_name, model) {
  choices <- c(
    "Just for this R session",
    "In this and future R sessions"
  )

  selection <- utils::menu(
    choices,
    title = "Store this configuration..."
  )

  if (selection == 0 || selection == 1) {
    return(invisible(NULL))
  }

  persist_client_option(fn_name, model)

  invisible(NULL)
}

provider_available <- function(chat_fn) {
  available <- tryCatch(
    {
      suppressWarnings(suppressMessages(chat_fn()))
      TRUE
    },
    error = function(e) FALSE
  )
  available
}

persist_client_option <- function(fn_name, model) {
  proj_rprofile <- ".Rprofile"
  use_project <- file.exists(proj_rprofile)

  rprofile_path <- if (use_project) {
    proj_rprofile
  } else {
    path.expand("~/.Rprofile")
  }

  option_line <- sprintf(
    'options(side.client = ellmer::%s(model = "%s"))',
    fn_name,
    model
  )

  if (file.exists(rprofile_path)) {
    existing <- readLines(rprofile_path, warn = FALSE)
  } else {
    existing <- character(0)
  }

  if (any(grepl("side.client", existing, fixed = TRUE))) {
    cli::cli_abort(
      "A {.code side.client} option already exists in {.file {rprofile_path}}."
    )
  }

  new_content <- c(existing, "", option_line)
  writeLines(new_content, rprofile_path)

  cli::cli_alert_success(
    "Added {.code {option_line}} to {.file {rprofile_path}}."
  )

  invisible(NULL)
}
