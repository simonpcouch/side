shell_impl <- function(command, description, cwd = NULL, timeout_ms = 120000, env_vars = NULL, `_intent` = NULL) {
  check_string(command)
  check_string(description)

  if (!is.null(cwd)) {
    check_string(cwd)
    if (!dir.exists(cwd)) {
      cli::cli_abort("Working directory {.path {cwd}} does not exist.", call = rlang::caller_env())
    }
  }

  if (!is.null(timeout_ms)) {
    check_number_whole(timeout_ms)
    if (timeout_ms < 1 || timeout_ms > 600000) {
      cli::cli_abort(
        "timeout_ms must be between 1 and 600000 (10 minutes).",
        call = rlang::caller_env()
      )
    }
  }

  if (is_dangerous_command(command)) {
    cli::cli_warn(c(
      "!" = "This command is potentially dangerous: {.code {command}}",
      "i" = "Dangerous operations include: git reset/rm, rm -f/-rf, git push --force, git clean -fd"
    ))
  }

  env <- if (!is.null(env_vars)) {
    parsed_env <- jsonlite::fromJSON(env_vars, simplifyVector = FALSE)
    if (!is.list(parsed_env)) {
      cli::cli_abort("env_vars must be a JSON object", call = rlang::caller_env())
    }
    env_list <- unlist(parsed_env)
    c(Sys.getenv(), env_list)
  } else {
    character(0)
  }

  timeout_sec <- if (!is.null(timeout_ms)) timeout_ms / 1000 else 120

  result <- processx::run(
    "bash",
    c("-c", command),
    wd = cwd,
    env = env,
    timeout = timeout_sec,
    error_on_status = FALSE,
    echo_cmd = FALSE,
    echo = FALSE
  )

  exit_code <- result$status
  stdout <- result$stdout
  stderr <- result$stderr

  success <- exit_code == 0

  value_text <- if (success) {
    if (nchar(stdout) > 0) stdout else "Command completed successfully"
  } else {
    sprintf("Command failed with exit code %d\n%s", exit_code, stderr)
  }

  output_display <- format_shell_output(command, stdout, stderr, exit_code, description)

  ellmer::ContentToolResult(
    value = value_text,
    extra = list(
      command = command,
      exit_code = exit_code,
      stdout = stdout,
      stderr = stderr,
      display = list(
        markdown = output_display,
        title = htmltools::HTML(sprintf(
          "%s <code>%s</code>",
          if (success) "\u2705" else "\u274c",
          description
        )),
        icon = tool_icon("code-blocks"),
        show_request = FALSE,
        open = !success || nchar(stderr) > 0 || nchar(stdout) > 500
      )
    )
  )
}

format_shell_output <- function(command, stdout, stderr, exit_code, description) {
  lines <- character()

  lines <- c(lines, sprintf("**Command:** `%s`", command))
  lines <- c(lines, sprintf("**Exit code:** %d", exit_code))
  lines <- c(lines, "")

  if (nchar(stdout) > 0) {
    lines <- c(lines, "**Output:**")
    lines <- c(lines, "```")
    lines <- c(lines, stdout)
    lines <- c(lines, "```")
    lines <- c(lines, "")
  }

  if (nchar(stderr) > 0) {
    lines <- c(lines, "**Errors:**")
    lines <- c(lines, "```")
    lines <- c(lines, stderr)
    lines <- c(lines, "```")
  }

  paste(lines, collapse = "\n")
}

tool_shell <- function() {
  ellmer::tool(
    shell_impl,
    name = "shell",
    description = paste(
      "Execute shell commands for terminal operations like git, package managers, system tools, etc.",
      "This tool is for TERMINAL OPERATIONS ONLY.",
      "DO NOT use for file operations - use specialized tools instead:",
      "- File search: use btw_tool_files_list_files (NOT find or ls)",
      "- Content search: use btw_tool_files_code_search (NOT grep)",
      "- Read files: use read_text_file (NOT cat/head/tail)",
      "- Edit files: use write_text_file (NOT sed/awk)",
      "- Write files: use write_text_file (NOT echo > or cat << EOF)",
      "",
      "Command chaining:",
      "- For sequential dependent commands, use && to chain (e.g., 'cd dir && ls')",
      "- Use ';' only when you don't care if earlier commands fail",
      "- DO NOT use newlines to separate commands within a single command string",
      "",
      "Git safety:",
      "- NEVER use git push --force without explicit user approval",
      "- NEVER use git reset --hard without explicit user approval",
      "- NEVER use git clean -fd without explicit user approval",
      "- Check git authorship before amending commits",
      "- Only commit when user explicitly asks"
    ),
    arguments = list(
      command = ellmer::type_string(
        "The shell command to execute. Use && to chain dependent commands."
      ),
      description = ellmer::type_string(
        "Clear, concise description of what this command does (5-10 words, active voice). Examples: 'Install package dependencies', 'Show git status', 'Run test suite'"
      ),
      cwd = ellmer::type_string(
        "Working directory for command execution. If not specified, uses current working directory.",
        required = FALSE
      ),
      timeout_ms = ellmer::type_number(
        "Timeout in milliseconds (default: 120000, max: 600000). Commands exceeding timeout will be terminated.",
        required = FALSE
      ),
      env_vars = ellmer::type_string(
        "JSON string of environment variables as key-value pairs (e.g., '{\"VAR1\": \"value1\", \"VAR2\": \"value2\"}'). Optional.",
        required = FALSE
      ),
      `_intent` = ellmer::type_string(
        "Brief description of why you're running this command",
        required = FALSE
      )
    ),
    convert = FALSE,
    annotations = ellmer::tool_annotations(
      icon = tool_icon("code-blocks")
    )
  )
}

swap_shell <- function(client, socket_url = NULL) {
  custom_tool <- tool_shell()

  if (!is.null(socket_url)) {
    custom_tool <- reroute_tool(custom_tool, socket_url)
  }

  client$register_tool(custom_tool)

  invisible(client)
}

is_dangerous_command <- function(command) {
  check_string(command)

  parts <- parse_command(command)

  if (is_shell_wrapper(parts)) {
    embedded_cmd <- extract_shell_command(command)
    if (!is.null(embedded_cmd)) {
      return(is_dangerous_to_call_with_exec(embedded_cmd))
    }
  }

  is_dangerous_to_call_with_exec(command)
}

parse_command <- function(command) {
  trimmed <- trimws(command)

  parts <- strsplit(trimmed, "\\s+")[[1]]

  parts[parts != ""]
}

is_shell_wrapper <- function(parts) {
  if (length(parts) == 0) return(FALSE)

  shell_commands <- c("bash", "sh", "zsh", "fish")
  first <- basename(parts[1])

  if (!first %in% shell_commands) return(FALSE)

  if (length(parts) < 3) return(FALSE)

  any(parts[2] %in% c("-c", "-lc"))
}

extract_shell_command <- function(command) {
  parts <- parse_command(command)

  c_idx <- which(parts %in% c("-c", "-lc"))
  if (length(c_idx) == 0) return(NULL)

  c_idx <- c_idx[1]

  if (c_idx >= length(parts)) return(NULL)

  remaining <- paste(parts[(c_idx + 1):length(parts)], collapse = " ")

  remaining <- gsub("^['\"]|['\"]$", "", remaining)

  remaining
}

is_dangerous_to_call_with_exec <- function(command) {
  parts <- parse_command(command)

  if (length(parts) == 0) return(FALSE)

  cmd <- basename(parts[1])

  if (cmd == "sudo") {
    if (length(parts) < 2) return(FALSE)

    sudo_command <- paste(parts[-1], collapse = " ")
    return(is_dangerous_to_call_with_exec(sudo_command))
  }

  if (cmd == "git") {
    return(is_dangerous_git_command(parts[-1]))
  }

  if (cmd == "rm") {
    return(is_dangerous_rm_command(parts[-1]))
  }

  FALSE
}

is_dangerous_git_command <- function(args) {
  if (length(args) == 0) return(FALSE)

  subcommand <- args[1]

  if (subcommand %in% c("reset", "rm")) {
    return(TRUE)
  }

  if (subcommand == "push") {
    return(any(grepl("^(-f|--force)$", args[-1])))
  }

  if (subcommand == "clean") {
    return(any(grepl("^-[a-z]*[fd]", args[-1])))
  }

  FALSE
}

is_dangerous_rm_command <- function(args) {
  if (length(args) == 0) return(FALSE)

  any(grepl("^-[a-zA-Z]*[fF]", args))
}
