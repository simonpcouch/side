update_plan_impl <- function(steps, `_intent` = NULL) {
  validate_plan_steps(steps, call = rlang::caller_env())

  the$plan <- list(
    steps = steps,
    last_updated = Sys.time()
  )

  display_text <- format_plan_display(steps, `_intent`)

  ellmer::ContentToolResult(
    value = display_text,
    extra = list(
      display = list(
        title = "Plan",
        markdown = display_text,
        show_request = FALSE,
        open = TRUE
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

format_plan_display <- function(steps, intent = NULL) {
  status_icons <- c(
    "pending" = "\u26aa",
    "in_progress" = "\u25b6\ufe0f",
    "completed" = "\u2705"
  )

  n_total <- length(steps)
  n_completed <- sum(vapply(steps, function(x) x$status == "completed", logical(1)))
  pct_complete <- if (n_total > 0) round(100 * n_completed / n_total) else 0

  bar_width <- 60
  n_filled <- round(bar_width * n_completed / n_total)
  n_empty <- bar_width - n_filled

  lines <- vapply(seq_along(steps), function(i) {
    step <- steps[[i]]
    icon <- status_icons[[step$status]]

    desc <- if (step$status == "in_progress") {
      paste0("**", step$description, "**")
    } else {
      step$description
    }

    paste0(i, ". ", icon, " ", desc)
  }, character(1))

  result <- paste0(
    n_completed, " of ", n_total, " steps completed (", pct_complete, "%)\n\n",
    paste(lines, collapse = "\n")
  )

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
      "(unless all steps are 'completed' or 'pending').",
      "Use _intent to briefly describe what you're moving on to next (and don't mention what you just completed--that will be handled by the UI automatically)."
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
        "Brief description of what you're moving on to next. Do not mention the task that you just completed in this step, as that will be shown in the UI automatically."
      )
    ),
    convert = FALSE,
    annotations = ellmer::tool_annotations(
      icon = tool_icon("new-label")
    )
  )
}
