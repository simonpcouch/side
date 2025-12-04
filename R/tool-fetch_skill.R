fetch_skill_impl <- function(skill_name, `_intent` = NULL) {
  skill_info <- find_skill(skill_name)

  if (is.null(skill_info)) {
    available <- list_available_skills()
    skill_names <- vapply(available, function(x) x$name, character(1))
    cli::cli_abort(
      c(
        "Skill {.val {skill_name}} not found.",
        "i" = "Available skills: {.val {skill_names}}"
      ),
      call = rlang::caller_env()
    )
  }

  skill_content <- readLines(skill_info$path, warn = FALSE)

  # Remove YAML frontmatter if present
  content_start <- 1
  if (length(skill_content) > 0 && skill_content[1] == "---") {
    yaml_end <- which(skill_content == "---")
    if (length(yaml_end) >= 2) {
      content_start <- yaml_end[2] + 1
    }
  }

  skill_text <- paste(
    skill_content[content_start:length(skill_content)],
    collapse = "\n"
  )

  resources <- list_skill_resources(skill_info$base_dir)
  resources_listing <- format_resources_listing(resources, skill_name)

  full_content <- paste0(skill_text, resources_listing)

  ellmer::ContentToolResult(
    value = full_content,
    extra = list(
      display = list(
        markdown = full_content,
        title = htmltools::HTML(sprintf(
          "Skill: <code>%s</code>",
          skill_name
        )),
        icon = tool_icon("globe-book"),
        open = TRUE
      )
    )
  )
}

find_skill <- function(skill_name) {
  skill_dirs <- get_skill_directories()

  for (dir in skill_dirs) {
    skill_dir <- file.path(dir, skill_name)
    skill_md_path <- file.path(skill_dir, "SKILL.md")
    if (dir.exists(skill_dir) && file.exists(skill_md_path)) {
      return(list(
        path = skill_md_path,
        base_dir = skill_dir
      ))
    }
  }

  NULL
}

get_skill_directories <- function() {
  dirs <- character()

  # Built-in skills from package
  package_skills <- system.file("skills", package = "side")
  if (nzchar(package_skills) && dir.exists(package_skills)) {
    dirs <- c(dirs, package_skills)
  }

  # User skills from config directory (configurable via option)
  user_skills_dir <- getOption("side.skills_dir", default_user_skills_dir())
  if (dir.exists(user_skills_dir)) {
    dirs <- c(dirs, user_skills_dir)
  }

  dirs
}

default_user_skills_dir <- function() {
  if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("APPDATA"), "side", "skills")
  } else {
    file.path(Sys.getenv("HOME"), ".config", "side", "skills")
  }
}

list_available_skills <- function() {
  skill_dirs <- get_skill_directories()
  all_skills <- list()

  for (dir in skill_dirs) {
    if (!dir.exists(dir)) {
      next
    }

    subdirs <- list.dirs(dir, full.names = TRUE, recursive = FALSE)

    for (subdir in subdirs) {
      skill_md_path <- file.path(subdir, "SKILL.md")
      if (file.exists(skill_md_path)) {
        metadata <- extract_skill_metadata(skill_md_path)
        skill_name <- basename(subdir)

        # User skills override built-in skills with same name
        if (!skill_name %in% names(all_skills)) {
          all_skills[[skill_name]] <- list(
            name = skill_name,
            description = metadata$description %||% "No description available",
            path = skill_md_path
          )
        }
      }
    }
  }

  all_skills
}

extract_skill_metadata <- function(skill_path) {
  lines <- readLines(skill_path, warn = FALSE)

  if (length(lines) == 0 || lines[1] != "---") {
    return(list())
  }

  yaml_end_indices <- which(lines == "---")
  if (length(yaml_end_indices) < 2) {
    return(list())
  }

  yaml_lines <- lines[2:(yaml_end_indices[2] - 1)]
  yaml_text <- paste(yaml_lines, collapse = "\n")

  tryCatch(
    yaml::yaml.load(yaml_text),
    error = function(e) list()
  )
}

format_skills_section <- function() {
  skills <- list_available_skills()

  if (length(skills) == 0) {
    return("")
  }

  # Read the skills explanation prompt
  skills_prompt_path <- system.file("prompts", "skills.md", package = "side")
  explanation <- if (file.exists(skills_prompt_path)) {
    paste(readLines(skills_prompt_path, warn = FALSE), collapse = "\n")
  } else {
    "## Skills\n\nYou have access to specialized skills that provide detailed guidance for specific tasks."
  }

  # Format the list of available skills
  skill_items <- vapply(
    skills,
    function(skill) {
      paste0("- **", skill$name, "**: ", skill$description)
    },
    character(1)
  )

  paste0(
    explanation,
    "\n\n**Available skills:**\n\n",
    paste(skill_items, collapse = "\n"),
    "\n\nTo use a skill, call `fetch_skill(skill_name = \"skill-name\")`."
  )
}

list_skill_resources <- function(skill_dir) {
  list(
    scripts = list_files_in_subdir(skill_dir, "scripts"),
    references = list_files_in_subdir(skill_dir, "references"),
    assets = list_files_in_subdir(skill_dir, "assets")
  )
}

list_files_in_subdir <- function(base_dir, subdir) {
  full_path <- file.path(base_dir, subdir)
  if (!dir.exists(full_path)) {
    return(character(0))
  }
  list.files(full_path, full.names = FALSE)
}

has_resources <- function(resources) {
  length(resources$scripts) > 0 ||
    length(resources$references) > 0 ||
    length(resources$assets) > 0
}

format_resources_listing <- function(resources, skill_name) {
  if (!has_resources(resources)) {
    return("")
  }

  parts <- character()

  parts <- c(parts, "\n\n---\n\n## Bundled Resources\n")
  parts <- c(parts, "This skill includes bundled resources that you can access on-demand:\n")

  if (length(resources$scripts) > 0) {
    parts <- c(parts, "\n### Executable Scripts\n")
    script_list <- paste0("- `", resources$scripts, "`", collapse = "\n")
    parts <- c(parts, script_list)
    parts <- c(parts, sprintf(
      "\n\nExecute a script: `execute_skill_script(skill_name = \"%s\", script = \"script-name\")`",
      skill_name
    ))
  }

  if (length(resources$references) > 0) {
    parts <- c(parts, "\n\n### Reference Documentation\n")
    ref_list <- paste0("- `", resources$references, "`", collapse = "\n")
    parts <- c(parts, ref_list)
    parts <- c(parts, sprintf(
      "\n\nFetch a reference: `fetch_skill_reference(skill_name = \"%s\", reference = \"reference-name\")`",
      skill_name
    ))
  }

  if (length(resources$assets) > 0) {
    parts <- c(parts, "\n\n### Asset Templates\n")
    asset_list <- paste0("- `", resources$assets, "`", collapse = "\n")
    parts <- c(parts, asset_list)
    parts <- c(parts, sprintf(
      "\n\nGet an asset: `get_skill_asset(skill_name = \"%s\", asset = \"asset-name\")`",
      skill_name
    ))
  }

  paste(parts, collapse = "")
}

tool_fetch_skill <- function() {
  ellmer::tool(
    fetch_skill_impl,
    name = "fetch_skill",
    description = paste(
      "Fetch a specialized skill that provides detailed guidance for a specific task.",
      "Skills are markdown documents with instructions for tasks like writing tests,",
      "creating documentation, or following specific coding patterns.",
      "Use this when you need detailed guidance for a specialized task."
    ),
    arguments = list(
      skill_name = ellmer::type_string(
        "The name of the skill to fetch (without .md extension)"
      ),
      `_intent` = ellmer::type_string(
        "The intent of the tool call that describes why you called this tool."
      )
    ),
    convert = FALSE
  )
}
