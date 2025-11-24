test_that("fetch_skill_impl fetches skill with YAML frontmatter", {
  skill_path <- system.file("skills", "write-unit-tests.md", package = "side")
  skill_content <- readLines(skill_path, warn = FALSE)

  result <- fetch_skill_impl("write-unit-tests")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_type(result@value, "character")
  expect_true(nchar(result@value) > 0)
  expect_false(grepl("^---", result@value))
  expect_true(grepl("Unit testing", result@value))
  expect_equal(result@extra$display$icon, tool_icon("globe-book"))
  expect_true(result@extra$display$open)
})

test_that("fetch_skill_impl errors informatively when skill not found", {
  expect_snapshot(fetch_skill_impl("nonexistent-skill"), error = TRUE)
})

test_that("fetch_skill_impl handles skills without YAML frontmatter", {
  withr::local_tempdir()
  skill_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_dir, showWarnings = FALSE)
  skill_file <- file.path(skill_dir, "test-skill.md")
  writeLines(c("# Test Skill", "Content without frontmatter"), skill_file)

  withr::local_options(side.skills_dir = skill_dir)

  result <- fetch_skill_impl("test-skill")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("# Test Skill", result@value))
  expect_true(grepl("Content without frontmatter", result@value))
})

test_that("find_skill returns NULL when skill doesn't exist", {
  expect_null(find_skill("definitely-does-not-exist"))
})

test_that("find_skill returns path when skill exists", {
  expected_path <- system.file(
    "skills",
    "write-unit-tests.md",
    package = "side"
  )
  result <- find_skill("write-unit-tests")
  expect_equal(result, expected_path)
})

test_that("get_skill_directories returns built-in skills directory", {
  dirs <- get_skill_directories()
  expect_true(length(dirs) >= 1)
  expect_true(any(grepl("side.*skills", dirs)))
})

test_that("list_available_skills returns expected structure", {
  skills <- list_available_skills()
  expect_type(skills, "list")
  expect_true(length(skills) > 0)
  expect_true(all(vapply(
    skills,
    function(x) {
      all(c("name", "description", "path") %in% names(x))
    },
    logical(1)
  )))
})

test_that("extract_skill_metadata extracts YAML frontmatter", {
  skill_path <- system.file("skills", "write-unit-tests.md", package = "side")
  metadata <- extract_skill_metadata(skill_path)
  expect_type(metadata, "list")
  expect_equal(metadata$name, "write-unit-tests")
  expect_type(metadata$description, "character")
})

test_that("extract_skill_metadata handles files without frontmatter", {
  withr::local_tempdir()
  test_file <- tempfile(fileext = ".md")
  writeLines(c("# No frontmatter", "Just content"), test_file)

  result <- extract_skill_metadata(test_file)
  expect_equal(result, list())
})

test_that("extract_skill_metadata handles empty files", {
  withr::local_tempdir()
  test_file <- tempfile(fileext = ".md")
  writeLines(character(0), test_file)

  result <- extract_skill_metadata(test_file)
  expect_equal(result, list())
})

test_that("default_user_skills_dir returns platform-specific path", {
  path <- default_user_skills_dir()
  if (.Platform$OS.type == "windows") {
    expect_match(path, "APPDATA")
  } else {
    expect_match(path, "\\.config")
  }
  expect_match(path, "side.*skills")
})
