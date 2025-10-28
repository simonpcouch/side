cli::cli_alert_info('Welcome to `side::kick()`! You\'ll be redirected back to the console shortly.')

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(btw)
  library(ellmer)
  library(shinychat)
})

if (!requireNamespace('side', quietly = TRUE)) {
  stop('side package must be installed')
}

addResourcePath("side", system.file("www", package = "side"))

working_dir <- '{{working_dir}}'
.persist <- {{persist}}

chat_files <- side:::get_chat_files(working_dir, persist = .persist)
if (length(chat_files) > 0) {
  {{client_code}}
  client <- side:::load_chat(chat_files[1], client)
  client$set_tools(side:::sidekick_tools('{{env_url}}'))
} else {
  {{client_code}}
  client$set_tools(side:::sidekick_tools('{{env_url}}'))
}

current_file <- shiny::reactiveVal(if (length(chat_files) > 0) chat_files[1] else NULL)

ui <- function(req) {
  bslib::page_fillable(
    tags$head(
      tags$script(src = "side/tool-approval.js"),
      tags$link(rel = "stylesheet", href = "side/tool-approval.css"),
      tags$style(HTML("
        .chat-menu-btn {
          position: fixed;
          top: 6px;
          left: 6px;
          z-index: 1000;
          background: none;
          border: none;
          font-size: 24px;
          cursor: pointer;
          padding: 0;
          width: 32px;
          height: 32px;
          line-height: 32px;
          text-align: center;
          color: #6c757d;
        }
        .close-btn {
          position: fixed;
          top: 6px;
          right: 6px;
          z-index: 1000;
        }
        .chat-dropdown {
          position: fixed;
          top: 44px;
          left: 6px;
          background: white;
          border: 1px solid #dee2e6;
          border-radius: 4px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          z-index: 1001;
          min-width: 280px;
          max-width: 400px;
          max-height: 400px;
          overflow-y: auto;
          display: none;
        }
        .chat-dropdown.show {
          display: block;
        }
        .chat-menu-item {
          padding: 10px 16px;
          cursor: pointer;
          border-bottom: 1px solid #f0f0f0;
          white-space: nowrap;
          font-size: 14px;
          color: #333;
        }
        .chat-menu-item:hover {
          background: #f8f9fa;
        }
        .chat-menu-item:last-child {
          border-bottom: none;
        }
      "))
    ),
    shinychat::chat_mod_ui("chat", height = "100%"),
    tags$button(
      class = "chat-menu-btn",
      id = "chat_menu_btn",
      onclick = "document.getElementById('chat_dropdown').classList.toggle('show')",
      "+"
    ),
    tags$div(
      id = "chat_dropdown",
      class = "chat-dropdown",
      style = "padding: 4px 0;",
      uiOutput("chat_menu_items")
    ),
    shiny::actionButton(
      "close_btn",
      label = "",
      class = "btn-close close-btn"
    ),
    tags$script(HTML("
      let interruptRequested = false;

      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && !interruptRequested) {
          interruptRequested = true;
          Shiny.setInputValue('interrupt_requested', Math.random(), {priority: 'event'});
        }
      });
    "))
  )
}

server <- function(input, output, session) {
  session$userData$approval_resolvers <- fastmap::fastmap()

  observeEvent(input$tool_approval_response, {
    response_data <- input$tool_approval_response
    request_id <- response_data$request_id

    resolver <- session$userData$approval_resolvers$get(request_id)
    if (!is.null(resolver)) {
      resolver(response_data$approved)
      session$userData$approval_resolvers$remove(request_id)
    }
  })

  side:::setup_tool_approval_callback(client, session)

  interrupt_flag <- reactiveVal(FALSE)

  chat_server <- side:::chat_mod_server_interruptible("chat", client, interrupt_flag)
  
  observeEvent(input$interrupt_requested, {
    if (!interrupt_flag()) {
      interrupt_flag(TRUE)
      chat_server$update_user_input(placeholder = "Interrupted--type to continue")
    }
  })

  observeEvent(chat_server$last_input(), {
    req(chat_server$last_input())
    chat_server$update_user_input(placeholder = "Esc to interrupt")
  })

  observeEvent(chat_server$last_turn(), {
    req(chat_server$last_turn())
    if (!interrupt_flag()) {
      chat_server$update_user_input(placeholder = "Enter a message")
    }
  })

  menu_trigger <- reactiveVal(0)

  output$chat_menu_items <- renderUI({
    menu_trigger()

    chat_files <- side:::get_chat_files(working_dir, persist = .persist)

    menu_items <- list(
      tags$div(
        class = "chat-menu-item",
        onclick = "Shiny.setInputValue('new_chat_click', Math.random()); document.getElementById('chat_dropdown').classList.remove('show');",
        "New chat"
      )
    )

    if (length(chat_files) > 0) {
      for (i in seq_along(chat_files)) {
        file <- chat_files[i]
        label <- side:::get_chat_label(file)
        menu_items <- c(menu_items, list(
          tags$div(
            class = "chat-menu-item",
            onclick = sprintf(
              "Shiny.setInputValue('load_chat_click', '%s'); document.getElementById('chat_dropdown').classList.remove('show');",
              file
            ),
            label
          )
        ))
      }
    }

    shiny::tagList(menu_items)
  })

  outputOptions(output, "chat_menu_items", suspendWhenHidden = FALSE)

  observeEvent(input$new_chat_click, {
    current <- current_file()
    if (!is.null(current) || length(client$get_turns()) > 0) {
      filepath <- side:::save_chat(client, working_dir, persist = .persist, existing_file = current)
      if (is.null(current) && !is.null(filepath)) {
        current_file(filepath)
      }
      side:::delete_oldest_chats(working_dir, persist = .persist)
    }

    current_file(NULL)

    chat_server$clear(client_history = "clear")
    menu_trigger(menu_trigger() + 1)
  })

  observeEvent(input$load_chat_click, {
    req(input$load_chat_click)

    current <- current_file()
    if (!is.null(current) || length(client$get_turns()) > 0) {
      filepath <- side:::save_chat(client, working_dir, persist = .persist, existing_file = current)
      if (is.null(current) && !is.null(filepath)) {
        current_file(filepath)
      }
    }

    client <<- side:::load_chat(input$load_chat_click, client)
    current_file(input$load_chat_click)

    turns <- client$get_turns()

    chat_server$clear(client_history = "keep")

    for (turn in turns) {
      if (turn@role == "user") {
        text_contents <- Filter(
          function(c) inherits(c, "ContentText") || inherits(c, "ellmer::ContentText"),
          turn@contents
        )
        if (length(text_contents) > 0) {
          chat_server$append(text_contents[[1]]@text, role = "user")
        }
      } else if (turn@role == "assistant") {
        for (content in turn@contents) {
          if (inherits(content, "ContentText") || inherits(content, "ellmer::ContentText")) {
            chat_server$append(content@text, role = "assistant")
          } else if (inherits(content, "ContentToolRequest")) {
            chat_server$append(content, role = "assistant")
          } else if (inherits(content, "ContentToolResult")) {
            chat_server$append(content, role = "assistant")
          }
        }
      }
    }

    menu_trigger(menu_trigger() + 1)
  })

  shiny::observeEvent(input$close_btn, {
    current <- current_file()
    if (!is.null(current) || length(client$get_turns()) > 0) {
      filepath <- side:::save_chat(client, working_dir, persist = .persist, existing_file = current)
      if (is.null(current) && !is.null(filepath)) {
        current_file(filepath)
      }
    }
    shiny::stopApp()
  })

  session$onSessionEnded(function() {
    current <- current_file()
    if (!is.null(current) || length(client$get_turns()) > 0) {
      filepath <- side:::save_chat(client, working_dir, persist = .persist, existing_file = current)
      if (is.null(current) && !is.null(filepath)) {
        current_file(filepath)
      }
    }
    
    side:::stash_last_kick(client)
  })
}

shiny::shinyApp(ui, server, enableBookmarking = "url")
