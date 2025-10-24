update_plan_impl <- function(steps, `_intent` = NULL) {
  validate_plan_steps(steps, call = rlang::caller_env())

  previous_plan <- the$plan
  title <- generate_plan_title(steps, previous_plan)

  the$plan <- list(
    steps = steps,
    last_updated = Sys.time()
  )

  display_text <- format_plan_display(steps, `_intent`)

  ellmer::ContentToolResult(
    value = display_text,
    extra = list(
      display = list(
        markdown = display_text,
        title = htmltools::HTML(title)
      )
    )
  )
}

validate_plan_steps <- function(steps, call = rlang::caller_env()) {
  if (length(steps) == 0) {
    cli::cli_abort("Plan must contain at least one step.", call = call)
  }

  valid_statuses <- c("pending", "in_progress", "completed")

  for (i in seq_along(steps)) {
    step <- steps[[i]]

    if (!is.list(step) || !"description" %in% names(step) || !"status" %in% names(step)) {
      cli::cli_abort(
        "Step {i} must have 'description' and 'status' fields.",
        call = call
      )
    }

    if (!step$status %in% valid_statuses) {
      cli::cli_abort(
        "Step {i} has invalid status {.val {step$status}}. Must be one of {.val {valid_statuses}}.",
        call = call
      )
    }
  }

  statuses <- vapply(steps, function(x) x$status, character(1))
  in_progress_count <- sum(statuses == "in_progress")
  all_complete <- all(statuses == "completed")
  all_pending <- all(statuses == "pending")

  if (!all_complete && !all_pending && in_progress_count != 1) {
    cli::cli_abort(
      "Plan must have exactly one 'in_progress' step (unless all steps are 'completed' or 'pending').",
      call = call
    )
  }

  invisible(NULL)
}

generate_plan_title <- function(steps, previous_plan) {
  if (is.null(previous_plan)) {
    return("Create plan")
  }

  completed_step <- NULL
  in_progress_step <- NULL

  previous_steps <- previous_plan$steps

  for (i in seq_along(steps)) {
    current_status <- steps[[i]]$status
    previous_status <- if (i <= length(previous_steps)) previous_steps[[i]]$status else NULL

    if (!is.null(previous_status) && previous_status != "completed" && current_status == "completed") {
      completed_step <- steps[[i]]$description
    }

    if (current_status == "in_progress") {
      previous_in_progress <- !is.null(previous_status) && previous_status == "in_progress"
      if (!previous_in_progress) {
        in_progress_step <- steps[[i]]$description
      }
    }
  }

  if (is.null(completed_step) && is.null(in_progress_step)) {
    return("Create plan")
  }

  title_parts <- c()
  if (!is.null(completed_step)) {
    title_parts <- c(title_parts, paste0("\u2713 ", completed_step))
  }
  if (!is.null(in_progress_step)) {
    title_parts <- c(title_parts, paste0("\u2192 ", in_progress_step))
  }

  paste(title_parts, collapse = "\n")
}

format_plan_display <- function(steps, intent = NULL) {
  status_icons <- c(
    "pending" = "\u25cb",
    "in_progress" = "\u2192",
    "completed" = "\u2713"
  )

  lines <- vapply(steps, function(step) {
    icon <- status_icons[[step$status]]
    paste0("- ", icon, " ", step$description)
  }, character(1))

  result <- paste(lines, collapse = "\n")

  if (!is.null(intent) && nzchar(intent)) {
    result <- paste0("**Plan Update**\n", intent, "\n\n", result)
  }

  result
}

tool_update_plan <- function() {
  ellmer::tool(
    update_plan_impl,
    name = "update_plan",
    description = paste(
      "Update the step-by-step plan for the current task.",
      "Use this to create a new plan, mark steps as in_progress or completed,",
      "or revise the plan mid-task.",
      "Each step should be a brief description (5-7 words).",
      "There should be exactly one 'in_progress' step at a time",
      "(unless all steps are 'completed' or 'pending')."
    ),
    arguments = list(
      steps = ellmer::type_array(
        items = ellmer::type_object(
          description = ellmer::type_string(
            "Brief description of the step (5-7 words)"
          ),
          status = ellmer::type_string(
            "Status of the step: 'pending', 'in_progress', or 'completed'"
          )
        ),
        description = "List of plan steps with descriptions and statuses"
      ),
      `_intent` = ellmer::type_string(
        "Optional explanation for why the plan was revised (use when changing plan mid-task)"
      )
    ),
    convert = FALSE
  )
}
