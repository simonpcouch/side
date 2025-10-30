#' @noRd
chat_mod_server_interruptible <- function(id, client, interrupt_flag) {

  append_stream_task <- shiny::ExtendedTask$new(
    function(client, ui_id, user_input, interrupt_flag) {
      stream <- client$stream_async(
        user_input,
        stream = "content"
      )

      p <- promises::promise_resolve(stream)
      promises::then(p, function(stream) {
        chat_append_interruptible(ui_id, stream, interrupt_flag)
      })
    }
  )

  shiny::moduleServer(id, function(input, output, session) {
    shinychat::chat_restore(
      "chat",
      client,
      session = session
    )

    last_turn <- shiny::reactiveVal(NULL, label = "last_turn")
    last_input <- shiny::reactiveVal(NULL, label = "last_input")
    
    shiny::observeEvent(input$chat_user_input, label = "on_chat_user_input", {
      if (shiny::isolate(interrupt_flag())) {
        clean_incomplete_tool_requests(client)
        interrupt_flag(FALSE)
      }

      last_input(input$chat_user_input)

      append_stream_task$invoke(
        client,
        "chat",
        input$chat_user_input,
        interrupt_flag
      )
    })
    
    shiny::observe(label = "update_last_turn", {
      if (append_stream_task$status() == "success") {
        last_turn(client$last_turn())
      }
    })
    
    chat_update_user_input <- function(
      value = NULL,
      ...,
      placeholder = NULL,
      submit = FALSE,
      focus = FALSE
    ) {
      shinychat::update_chat_user_input(
        "chat",
        value = value,
        placeholder = placeholder,
        submit = submit,
        focus = focus,
        ...,
        session = session
      )
    }
    
    chat_append_mod <- function(response, role = "assistant", icon = NULL) {
      shinychat::chat_append("chat", response, role = role, icon = icon, session = session)
    }
    
    client_clear <- function(
      messages = NULL,
      client_history = c("clear", "set", "append", "keep")
    ) {
      client_history <- rlang::arg_match(client_history)
      
      if (!is.null(messages)) {
        if (rlang::is_string(messages)) {
          messages <- list(list(role = "assistant", content = messages))
        }
        if (!rlang::is_list(messages)) {
          cli::cli_abort(
            "{.var messages} must be a list of messages, and each message must be a list with {.field role} and {.field content}."
          )
        }
        if (length(intersect(c("role", "content"), names(messages))) == 2) {
          messages <- list(messages)
        }
      }
      
      shinychat::chat_clear("chat", session = session)
      if (!is.null(messages)) {
        for (msg in messages) {
          shinychat::chat_append("chat", msg$content, role = msg$role, session = session)
        }
      }
      
      if (client_history == "clear") {
        client$set_turns(list())
      } else if (client_history == "set") {
        turns <- as_ellmer_turns(messages)
        client$set_turns(turns)
      } else if (client_history == "append") {
        turns <- client$get_turns()
        turns <- c(turns, as_ellmer_turns(messages))
        client$set_turns(turns)
      }
      
      last_turn(NULL)
      last_input(NULL)
    }

    # chat_restore() is designed for initial module setup and bookmarking, not
    # dynamic reloading. We expose this method to allow external code to reload
    # the chat UI while maintaining access to the module's session context.
    load_chat_ui <- function() {
      shinychat::chat_clear("chat", session = session)

      msgs <- shinychat::contents_shinychat(client)
      lapply(msgs, function(msg_turn) {
        is_list <- is.list(msg_turn$content) &&
          !inherits(msg_turn$content, c("shiny.tag", "shiny.taglist"))

        if (is_list) {
          stream <- coro::generator(function() {
            for (x in msg_turn$content) {
              coro::yield(x)
            }
          })
          shinychat::chat_append("chat", stream(), msg_turn$role, session = session)
        } else {
          shinychat::chat_append("chat", msg_turn$content, role = msg_turn$role, session = session)
        }
      })
    }

    list(
      last_turn = shiny::reactive(last_turn(), label = "mod_last_turn"),
      last_input = shiny::reactive(last_input(), label = "mod_last_input"),
      client = client,
      append = chat_append_mod,
      update_user_input = chat_update_user_input,
      clear = client_clear,
      load_chat = load_chat_ui
    )
  })
}

#' @noRd
chat_append_interruptible <- coro::async(function(
  id,
  stream,
  interrupt_flag,
  role = "assistant",
  icon = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
    chat_append_ <- function(content, chunk = TRUE, ...) {
      shinychat::chat_append_message(
        id,
        msg = list(role = role, content = content),
        operation = "append",
        chunk = chunk,
        session = session,
        ...
      )
    }
    
    chat_append_("", chunk = "start", icon = icon)
    
    res <- fastmap::fastqueue(200)
    
    interrupted <- FALSE
    for (msg in stream) {
      if (promises::is.promising(msg)) {
        msg <- await(msg)
      }
      if (coro::is_exhausted(msg)) {
        break
      }

      if (shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        break
      }

      res$add(msg)

      if (S7::S7_inherits(msg, ellmer::ContentToolResult)) {
        if (!is.null(msg@request)) {
          session$sendCustomMessage("shiny-tool-request-hide", msg@request@id)
        }
      }

      if (S7::S7_inherits(msg, ellmer::Content)) {
        msg <- shinychat::contents_shinychat(msg)
      }

      chat_append_(msg)
    }

    if (interrupted) {
      chat_append_(
        htmltools::tags$span(
          style = "color: #C55A11;",
          " [Interrupted.]"
        )
      )
    }

    chat_append_("", chunk = "end")

    res <- res$as_list()
    if (all(vapply(res, is.character, logical(1)))) {
      paste(unlist(res), collapse = "")
    } else {
      res
    }
})

#' @noRd
as_ellmer_turns <- function(messages) {
  if (is.null(messages) || length(messages) == 0) {
    return(list())
  }
  
  lapply(messages, function(msg) {
    role <- msg$role %||% "assistant"
    content <- msg$content %||% ""
    
    if (is.character(content)) {
      contents <- list(ellmer::ContentText(content))
    } else {
      contents <- list(content)
    }
    
    ellmer::Turn(role = role, contents = contents)
  })
}
