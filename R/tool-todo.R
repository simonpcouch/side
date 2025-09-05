#' Todo List Management Tool
#'
#' A tool for managing a todo list during agent interactions. This helps agents
#' track progress on complex tasks and avoid context rot.
#'
#' @return A tool definition for todo list management
#' @export
TodoWrite <- function() {
  tool(
    function(todos) {
      the$todos <- todos
      format_todos(todos)
    },
    description = "Create and manage a structured task list for your current session. Use this tool proactively to track progress, organize complex tasks, and demonstrate thoroughness.",
    arguments = list(
      todos = type_array(
        items = type_object(
          content = type_string("Task description in imperative form (e.g., 'Run tests', 'Build the project')"),
          status = type_string("Task status: 'pending', 'in_progress', or 'completed'"),
          activeForm = type_string("Present continuous form shown during execution (e.g., 'Running tests', 'Building the project')")
        ),
        description = "Array of todo items"
      )
    )
  )
}

format_todos <- function(todos) {
  if (length(todos) == 0) {
    return("Todo list is empty.")
  }
  
  status_icons <- c(
    "pending" = "⏳",
    "in_progress" = "🔄", 
    "completed" = "✅"
  )
  
  formatted <- character(length(todos))
  for (i in seq_along(todos)) {
    todo <- todos[[i]]
    icon <- status_icons[[todo$status]] %||% "❓"
    if (todo$status == "in_progress") {
      formatted[i] <- paste0(icon, " ", todo$activeForm)
    } else {
      formatted[i] <- paste0(icon, " ", todo$content)
    }
  }
  
  paste(formatted, collapse = "\n")
}
