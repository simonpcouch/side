test_that("fetch_skill_reference_impl reads reference file", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "references"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  ref_file <- file.path(skill_dir, "references", "guide.md")
  writeLines(c("# Reference Guide", "Additional details"), ref_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- fetch_skill_reference_impl("test-skill", "guide.md")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("Reference Guide", result@value))
  expect_true(grepl("Additional details", result@value))
  expect_equal(result@extra$display$icon, tool_icon("globe-book"))
})

test_that("fetch_skill_reference_impl errors when reference not found", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "references"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  expect_error(
    fetch_skill_reference_impl("test-skill", "missing.md"),
    "not found"
  )
})

test_that("fetch_skill_reference_impl errors when skill not found", {
  expect_error(
    fetch_skill_reference_impl("nonexistent-skill", "guide.md"),
    "not found"
  )
})

test_that("execute_skill_script_impl runs R scripts", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  script_file <- file.path(skill_dir, "scripts", "test.R")
  writeLines("2 + 2", script_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- execute_skill_script_impl("test-skill", "test.R")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("4", result@value))
})

test_that("execute_skill_script_impl runs shell scripts", {
  skip_on_os("windows")

  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  script_file <- file.path(skill_dir, "scripts", "test.sh")
  writeLines("echo 'Hello from shell'", script_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- execute_skill_script_impl("test-skill", "test.sh")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("Hello from shell", result@value))
})

test_that("execute_skill_script_impl errors for unsupported script types", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  script_file <- file.path(skill_dir, "scripts", "test.py")
  writeLines("print('test')", script_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  expect_error(
    execute_skill_script_impl("test-skill", "test.py"),
    "Unsupported script type"
  )
})

test_that("execute_skill_script_impl errors when script not found", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  expect_error(
    execute_skill_script_impl("test-skill", "missing.R"),
    "not found"
  )
})

test_that("get_skill_asset_impl reads asset files", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "assets"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  asset_file <- file.path(skill_dir, "assets", "template.R")
  writeLines(c("# Template", "function() {}"), asset_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- get_skill_asset_impl("test-skill", "template.R")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("Template", result@value))
  expect_true(grepl("function", result@value))
  expect_true(grepl("```R", result@extra$display$markdown))
})

test_that("get_skill_asset_impl formats code with syntax highlighting", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "assets"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  asset_file <- file.path(skill_dir, "assets", "config.json")
  writeLines('{"key": "value"}', asset_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- get_skill_asset_impl("test-skill", "config.json")

  expect_true(grepl("```json", result@extra$display$markdown))
})

test_that("get_skill_asset_impl errors when asset not found", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "assets"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines("Main skill", skill_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  expect_error(
    get_skill_asset_impl("test-skill", "missing.txt"),
    "not found"
  )
})
