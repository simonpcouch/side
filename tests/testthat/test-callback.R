test_that("requires_approval returns TRUE for write_text_file", {
  request <- ellmer::ContentToolRequest(
    id = "test_id",
    name = "write_text_file",
    arguments = list(path = "test.R")
  )
  expect_true(requires_approval(request))
})

test_that("requires_approval returns TRUE for dangerous shell commands", {
  request <- ellmer::ContentToolRequest(
    id = "test_id",
    name = "shell",
    arguments = list(command = "rm -rf /tmp")
  )
  expect_true(requires_approval(request))
})

test_that("requires_approval returns FALSE for safe shell commands", {
  request <- ellmer::ContentToolRequest(
    id = "test_id",
    name = "shell",
    arguments = list(command = "git status")
  )
  expect_false(requires_approval(request))
})

test_that("requires_approval returns FALSE for other tools", {
  request <- ellmer::ContentToolRequest(
    id = "test_id",
    name = "read_text_file",
    arguments = list(path = "test.R")
  )
  expect_false(requires_approval(request))
})

test_that("requires_approval handles NULL command in shell request", {
  request <- ellmer::ContentToolRequest(
    id = "test_id",
    name = "shell",
    arguments = list()
  )
  expect_false(requires_approval(request))
})
