test_that("should_persist returns TRUE when interactive", {
  withr::local_options(rlang_interactive = TRUE)
  expect_true(should_persist())
})

test_that("should_persist returns TRUE when NOT_CRAN is true", {
  withr::local_options(rlang_interactive = FALSE)
  withr::local_envvar(NOT_CRAN = "true")
  expect_true(should_persist())
})

test_that("should_persist returns FALSE in non-interactive non-CRAN mode", {
  withr::local_envvar(NOT_CRAN = NULL)
  testthat::local_mocked_bindings(interactive = function() FALSE)
  expect_false(should_persist())
})

test_that("truncate_text truncates by word count or character limit", {
  result_by_word <- truncate_text(
    "this is a very long sentence with many words",
    max_words = 4,
    max_chars = 100
  )
  expect_equal(result_by_word, "this is a very")

  result_by_char <- truncate_text(
    "verylongwordthatexceedsmaximumcharacterlimit",
    max_words = 10,
    max_chars = 20
  )
  expect_equal(result_by_char, "verylongwordthate...")
  expect_equal(nchar(result_by_char), 20)

  result_within_limits <- truncate_text(
    "short text",
    max_words = 10,
    max_chars = 100
  )
  expect_equal(result_within_limits, "short text")
})

test_that("sanitize_filename creates valid timestamped filenames", {
  expect_match(
    sanitize_filename("Hello World Test"),
    "^hello_world_test__\\d{8}_\\d{6}\\.rds$"
  )
  expect_match(
    sanitize_filename("Test!@#$%^&*()File"),
    "^test_file__\\d{8}_\\d{6}\\.rds$"
  )
  expect_match(
    sanitize_filename("one two three four five six seven"),
    "^one_two_three_four__\\d{8}_\\d{6}\\.rds$"
  )
})

test_that("check_inherits accepts matching class", {
  x <- structure(list(), class = "myclass")
  expect_null(check_inherits(x, "myclass"))
})

test_that("check_inherits errors informatively with wrong class", {
  expect_snapshot(check_inherits("a string", "myclass"), error = TRUE)
})

test_that("get_chat_dir returns temp dir when persist is FALSE", {
  result <- get_chat_dir(persist = FALSE)
  expect_equal(result, file.path(tempdir(), "side_chats"))
})

test_that("get_chat_dir returns platform-specific dir when persist is TRUE", {
  skip_on_cran()
  withr::local_envvar(HOME = tempdir(), APPDATA = tempdir())
  result <- get_chat_dir(persist = TRUE)

  if (.Platform$OS.type == "windows") {
    expect_match(result, "side.*chats")
  } else {
    expect_match(result, "\\.config.*side.*chats")
  }
})

test_that("extract_first_text extracts text from Turn contents", {
  turn_with_text <- ellmer::Turn(
    role = "user",
    contents = list(ellmer::ContentText("hello world"))
  )
  expect_equal(extract_first_text(turn_with_text), "hello world")

  turn_without_text <- ellmer::Turn(
    role = "user",
    contents = list()
  )
  expect_null(extract_first_text(turn_without_text))
})
