fetch_skill_reference_impl <- function(skill_name, reference, `_intent` = NULL) {
  check_string(skill_name)
  check_string(reference)

  skill_info <- find_skill(skill_name)

  if (is.null(skill_info)) {
    cli::cli_abort(
      "Skill {.val {skill_name}} not found.",
      call = rlang::caller_env()
    )
  }

  reference_path <- file.path(skill_info$base_dir, "references", reference)

  if (!file.exists(reference_path)) {
    cli::cli_abort(
      c(
        "Reference {.val {reference}} not found in skill {.val {skill_name}}.",
        "i" = "Available references: {.val {list.files(file.path(skill_info$base_dir, 'references'))}}"
      ),
      call = rlang::caller_env()
    )
  }

  content <- paste(readLines(reference_path, warn = FALSE), collapse = "\n")

  ellmer::ContentToolResult(
    value = content,
    extra = list(
      display = list(
        markdown = content,
        title = htmltools::HTML(sprintf(
          "Skill Reference: <code>%s/%s</code>",
          skill_name,
          reference
        )),
        icon = tool_icon("globe-book"),
        open = TRUE
      )
    )
  )
}

execute_skill_script_impl <- function(skill_name, script, `_intent` = NULL) {
  check_string(skill_name)
  check_string(script)

  skill_info <- find_skill(skill_name)

  if (is.null(skill_info)) {
    cli::cli_abort(
      "Skill {.val {skill_name}} not found.",
      call = rlang::caller_env()
    )
  }

  script_path <- file.path(skill_info$base_dir, "scripts", script)

  if (!file.exists(script_path)) {
    cli::cli_abort(
      c(
        "Script {.val {script}} not found in skill {.val {skill_name}}.",
        "i" = "Available scripts: {.val {list.files(file.path(skill_info$base_dir, 'scripts'))}}"
      ),
      call = rlang::caller_env()
    )
  }

  file_ext <- tools::file_ext(script)

  if (file_ext == "R") {
    code <- paste(readLines(script_path, warn = FALSE), collapse = "\n")
    run_r_code_impl(code = code, persist = FALSE, `_intent` = `_intent`)
  } else if (file_ext %in% c("sh", "bash")) {
    command <- paste("bash", shQuote(script_path))
    description <- sprintf("Execute skill script: %s", script)
    shell_impl(
      command = command,
      description = description,
      cwd = skill_info$base_dir,
      `_intent` = `_intent`
    )
  } else {
    cli::cli_abort(
      c(
        "Unsupported script type: {.val {file_ext}}",
        "i" = "Supported types: .R, .sh, .bash"
      ),
      call = rlang::caller_env()
    )
  }
}

get_skill_asset_impl <- function(skill_name, asset, `_intent` = NULL) {
  check_string(skill_name)
  check_string(asset)

  skill_info <- find_skill(skill_name)

  if (is.null(skill_info)) {
    cli::cli_abort(
      "Skill {.val {skill_name}} not found.",
      call = rlang::caller_env()
    )
  }

  asset_path <- file.path(skill_info$base_dir, "assets", asset)

  if (!file.exists(asset_path)) {
    cli::cli_abort(
      c(
        "Asset {.val {asset}} not found in skill {.val {skill_name}}.",
        "i" = "Available assets: {.val {list.files(file.path(skill_info$base_dir, 'assets'))}}"
      ),
      call = rlang::caller_env()
    )
  }

  content <- paste(readLines(asset_path, warn = FALSE), collapse = "\n")

  file_ext <- tools::file_ext(asset)
  display_content <- if (file_ext %in% c("R", "py", "js", "ts", "java", "c", "cpp", "sh", "bash", "json", "yaml", "yml", "xml", "html", "css", "md")) {
    paste0("```", file_ext, "\n", content, "\n```")
  } else {
    content
  }

  ellmer::ContentToolResult(
    value = content,
    extra = list(
      display = list(
        markdown = display_content,
        title = htmltools::HTML(sprintf(
          "Skill Asset: <code>%s/%s</code>",
          skill_name,
          asset
        )),
        icon = tool_icon("globe-book"),
        open = TRUE
      )
    )
  )
}

tool_fetch_skill_reference <- function() {
  ellmer::tool(
    fetch_skill_reference_impl,
    name = "fetch_skill_reference",
    description = paste(
      "Fetch a reference document from a skill's bundled resources.",
      "Reference documents provide additional documentation and examples for using the skill.",
      "Use this after fetching a skill to access its reference documentation."
    ),
    arguments = list(
      skill_name = ellmer::type_string(
        "The name of the skill"
      ),
      reference = ellmer::type_string(
        "The name of the reference document to fetch (including file extension)"
      ),
      `_intent` = ellmer::type_string(
        "The intent of the tool call that describes why you called this tool.",
        required = FALSE
      )
    ),
    convert = FALSE
  )
}

tool_execute_skill_script <- function() {
  ellmer::tool(
    execute_skill_script_impl,
    name = "execute_skill_script",
    description = paste(
      "Execute a script from a skill's bundled resources.",
      "Scripts can be R (.R) or shell (.sh, .bash) files that perform automated tasks.",
      "R scripts are executed in a fresh environment; shell scripts run in the skill directory.",
      "Use this after fetching a skill to run its executable scripts."
    ),
    arguments = list(
      skill_name = ellmer::type_string(
        "The name of the skill"
      ),
      script = ellmer::type_string(
        "The name of the script to execute (including file extension)"
      ),
      `_intent` = ellmer::type_string(
        "The intent of the tool call that describes why you called this tool.",
        required = FALSE
      )
    ),
    convert = FALSE
  )
}

tool_get_skill_asset <- function() {
  ellmer::tool(
    get_skill_asset_impl,
    name = "get_skill_asset",
    description = paste(
      "Get an asset template from a skill's bundled resources.",
      "Assets are template files (code, config, etc.) that can be used as starting points.",
      "Use this after fetching a skill to access its template files and resources."
    ),
    arguments = list(
      skill_name = ellmer::type_string(
        "The name of the skill"
      ),
      asset = ellmer::type_string(
        "The name of the asset to get (including file extension)"
      ),
      `_intent` = ellmer::type_string(
        "The intent of the tool call that describes why you called this tool.",
        required = FALSE
      )
    ),
    convert = FALSE
  )
}
