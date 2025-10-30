test_that("validate_plan_steps accepts valid plan with pending steps", {
  steps <- list(
    list(description = "Step one", status = "pending"),
    list(description = "Step two", status = "pending")
  )
  expect_null(validate_plan_steps(steps))
})

test_that("validate_plan_steps accepts valid plan with one in_progress", {
  steps <- list(
    list(description = "Step one", status = "completed"),
    list(description = "Step two", status = "in_progress"),
    list(description = "Step three", status = "pending")
  )
  expect_null(validate_plan_steps(steps))
})

test_that("validate_plan_steps accepts plan with all completed", {
  steps <- list(
    list(description = "Step one", status = "completed"),
    list(description = "Step two", status = "completed")
  )
  expect_null(validate_plan_steps(steps))
})

test_that("validate_plan_steps errors with empty plan", {
  expect_snapshot(validate_plan_steps(list()), error = TRUE)
})

test_that("validate_plan_steps errors with missing description", {
  steps <- list(
    list(status = "pending")
  )
  expect_snapshot(validate_plan_steps(steps), error = TRUE)
})

test_that("validate_plan_steps errors with missing status", {
  steps <- list(
    list(description = "Step one")
  )
  expect_snapshot(validate_plan_steps(steps), error = TRUE)
})

test_that("validate_plan_steps errors with invalid status", {
  steps <- list(
    list(description = "Step one", status = "invalid")
  )
  expect_snapshot(validate_plan_steps(steps), error = TRUE)
})

test_that("validate_plan_steps errors with multiple in_progress", {
  steps <- list(
    list(description = "Step one", status = "in_progress"),
    list(description = "Step two", status = "in_progress")
  )
  expect_snapshot(validate_plan_steps(steps), error = TRUE)
})

test_that("validate_plan_steps errors with no in_progress in mixed plan", {
  steps <- list(
    list(description = "Step one", status = "completed"),
    list(description = "Step two", status = "pending")
  )
  expect_snapshot(validate_plan_steps(steps), error = TRUE)
})

test_that("format_plan_display shows correct progress", {
  steps <- list(
    list(description = "First step", status = "completed"),
    list(description = "Second step", status = "in_progress"),
    list(description = "Third step", status = "pending")
  )
  result <- format_plan_display(steps)
  expect_match(result, "1 of 3 steps completed \\(33%\\)")
  expect_match(result, "First step")
  expect_match(result, "Second step")
  expect_match(result, "Third step")
})

test_that("format_plan_display bolds in_progress step", {
  steps <- list(
    list(description = "First step", status = "pending"),
    list(description = "Second step", status = "in_progress"),
    list(description = "Third step", status = "pending")
  )
  result <- format_plan_display(steps)
  expect_match(result, "\\*\\*Second step\\*\\*")
})

test_that("format_plan_display shows 100% when all completed", {
  steps <- list(
    list(description = "First step", status = "completed"),
    list(description = "Second step", status = "completed")
  )
  result <- format_plan_display(steps)
  expect_match(result, "2 of 2 steps completed \\(100%\\)")
})

test_that("format_plan_display shows 0% when all pending", {
  steps <- list(
    list(description = "First step", status = "pending"),
    list(description = "Second step", status = "pending")
  )
  result <- format_plan_display(steps)
  expect_match(result, "0 of 2 steps completed \\(0%\\)")
})
