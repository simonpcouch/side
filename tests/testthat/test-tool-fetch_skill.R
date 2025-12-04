test_that("fetch_skill_impl fetches skill with YAML frontmatter", {
  skill_path <- system.file(
    "skills",
    "write-unit-tests",
    "SKILL.md",
    package = "side"
  )
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
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines(c("# Test Skill", "Content without frontmatter"), skill_file)

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- fetch_skill_impl("test-skill")

  expect_s3_class(result, "ellmer::ContentToolResult")
  expect_true(grepl("# Test Skill", result@value))
  expect_true(grepl("Content without frontmatter", result@value))
})

test_that("find_skill returns NULL when skill doesn't exist", {
  expect_null(find_skill("definitely-does-not-exist"))
})

test_that("find_skill returns list with path and base_dir when skill exists", {
  result <- find_skill("write-unit-tests")
  expect_type(result, "list")
  expect_true(all(c("path", "base_dir") %in% names(result)))
  expect_true(grepl("SKILL.md$", result$path))
  expect_true(grepl("write-unit-tests$", result$base_dir))
  expect_true(file.exists(result$path))
  expect_true(dir.exists(result$base_dir))
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
  skill_path <- system.file(
    "skills",
    "write-unit-tests",
    "SKILL.md",
    package = "side"
  )
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

test_that("list_skill_resources lists all resource types", {
  withr::local_tempdir()
  skill_dir <- tempfile()
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)
  dir.create(file.path(skill_dir, "references"), showWarnings = FALSE)
  dir.create(file.path(skill_dir, "assets"), showWarnings = FALSE)

  writeLines("test", file.path(skill_dir, "scripts", "test.R"))
  writeLines("test", file.path(skill_dir, "references", "guide.md"))
  writeLines("test", file.path(skill_dir, "assets", "template.txt"))

  resources <- list_skill_resources(skill_dir)

  expect_type(resources, "list")
  expect_true("scripts" %in% names(resources))
  expect_true("references" %in% names(resources))
  expect_true("assets" %in% names(resources))
  expect_equal(resources$scripts, "test.R")
  expect_equal(resources$references, "guide.md")
  expect_equal(resources$assets, "template.txt")
})

test_that("list_skill_resources handles missing subdirectories", {
  withr::local_tempdir()
  skill_dir <- tempfile()
  dir.create(skill_dir, showWarnings = FALSE)

  resources <- list_skill_resources(skill_dir)

  expect_type(resources, "list")
  expect_length(resources$scripts, 0)
  expect_length(resources$references, 0)
  expect_length(resources$assets, 0)
})

test_that("has_resources detects presence of resources", {
  resources_with <- list(
    scripts = c("test.R"),
    references = character(0),
    assets = character(0)
  )
  expect_true(has_resources(resources_with))

  resources_without <- list(
    scripts = character(0),
    references = character(0),
    assets = character(0)
  )
  expect_false(has_resources(resources_without))
})

test_that("format_resources_listing creates markdown for resources", {
  resources <- list(
    scripts = c("setup.R", "test.sh"),
    references = c("guide.md"),
    assets = c("template.R")
  )

  formatted <- format_resources_listing(resources, "test-skill")

  expect_type(formatted, "character")
  expect_true(grepl("Bundled Resources", formatted))
  expect_true(grepl("setup.R", formatted))
  expect_true(grepl("test.sh", formatted))
  expect_true(grepl("guide.md", formatted))
  expect_true(grepl("template.R", formatted))
  expect_true(grepl("execute_skill_script", formatted))
  expect_true(grepl("fetch_skill_reference", formatted))
  expect_true(grepl("get_skill_asset", formatted))
})

test_that("format_resources_listing returns empty string for no resources", {
  resources <- list(
    scripts = character(0),
    references = character(0),
    assets = character(0)
  )

  formatted <- format_resources_listing(resources, "test-skill")
  expect_equal(formatted, "")
})

test_that("fetch_skill_impl appends resource listing when resources exist", {
  withr::local_tempdir()
  skill_base_dir <- file.path(tempdir(), "test_skills")
  dir.create(skill_base_dir, showWarnings = FALSE)
  skill_dir <- file.path(skill_base_dir, "test-skill")
  dir.create(skill_dir, showWarnings = FALSE)
  dir.create(file.path(skill_dir, "scripts"), showWarnings = FALSE)

  skill_file <- file.path(skill_dir, "SKILL.md")
  writeLines(c("# Test Skill", "Main content"), skill_file)
  writeLines("test", file.path(skill_dir, "scripts", "test.R"))

  withr::local_options(side.skills_dir = skill_base_dir)

  result <- fetch_skill_impl("test-skill")

  expect_true(grepl("Main content", result@value))
  expect_true(grepl("Bundled Resources", result@value))
  expect_true(grepl("test.R", result@value))
})
