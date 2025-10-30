test_that("validate_write_text_file_syntax accepts str_replace mode", {
  expect_null(
    validate_write_text_file_syntax(
      path = "test.R",
      insert_line = NULL,
      new_str = "new text",
      old_str = "old text"
    )
  )
})

test_that("validate_write_text_file_syntax accepts insert mode", {
  expect_null(
    validate_write_text_file_syntax(
      path = "test.R",
      insert_line = 1,
      new_str = "new text",
      old_str = NULL
    )
  )
})

test_that("validate_write_text_file_syntax errors informatively with invalid input", {
  expect_snapshot(
    validate_write_text_file_syntax(
      path = "test.R",
      insert_line = 1,
      new_str = "new text",
      old_str = "old text"
    ),
    error = TRUE
  )
  expect_snapshot(
    validate_write_text_file_syntax(
      path = "test.R",
      insert_line = NULL,
      new_str = "new text",
      old_str = NULL
    ),
    error = TRUE
  )
  expect_snapshot(
    validate_write_text_file_syntax(
      path = "test.R",
      insert_line = NULL,
      new_str = NULL,
      old_str = NULL
    ),
    error = TRUE
  )
})

test_that("handle_insert creates and modifies content correctly", {
  content_middle <- c("line 1", "line 2", "line 3")
  result_middle <- handle_insert(content_middle, insert_line = 1, new_str = "inserted", path = "test.R")
  expect_equal(result_middle$new_content, c("line 1", "inserted", "line 2", "line 3"))
  expect_equal(result_middle$added_lines, "inserted")
  expect_equal(result_middle$removed_lines, character(0))
  expect_equal(result_middle$operation, "Edit")

  result_create <- handle_insert(character(0), insert_line = 0, new_str = "first line", path = "test.R")
  expect_equal(result_create$new_content, "first line")
  expect_equal(result_create$operation, "Create")

  content_beginning <- c("line 1", "line 2")
  result_beginning <- handle_insert(content_beginning, insert_line = 0, new_str = "new first", path = "test.R")
  expect_equal(result_beginning$new_content, c("new first", "line 1", "line 2"))

  content_end <- c("line 1", "line 2")
  result_end <- handle_insert(content_end, insert_line = 2, new_str = "last line", path = "test.R")
  expect_equal(result_end$new_content, c("line 1", "line 2", "last line"))

  content_multiline <- c("line 1", "line 2")
  result_multiline <- handle_insert(content_multiline, insert_line = 1, new_str = "new line 1\nnew line 2", path = "test.R")
  expect_equal(result_multiline$new_content, c("line 1", "new line 1", "new line 2", "line 2"))
  expect_equal(result_multiline$added_lines, c("new line 1", "new line 2"))
})

test_that("handle_str_replace replaces single and multiline text", {
  content_single <- c("line 1", "old text", "line 3")
  result_single <- handle_str_replace(content_single, old_str = "old text", new_str = "new text", path = "test.R")
  expect_equal(result_single$new_content, c("line 1", "new text", "line 3"))
  expect_equal(result_single$removed_lines, "old text")
  expect_equal(result_single$added_lines, "new text")
  expect_equal(result_single$operation, "Edit")

  content_multiline <- c("line 1", "old line 1", "old line 2", "line 4")
  result_multiline <- handle_str_replace(
    content_multiline,
    old_str = "old line 1\nold line 2",
    new_str = "new line 1\nnew line 2",
    path = "test.R"
  )
  expect_equal(result_multiline$new_content, c("line 1", "new line 1", "new line 2", "line 4"))
  expect_equal(result_multiline$removed_lines, c("old line 1", "old line 2"))
  expect_equal(result_multiline$added_lines, c("new line 1", "new line 2"))
})
