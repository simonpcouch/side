test_that("git reset commands are flagged as dangerous", {
  expect_true(is_dangerous_command("git reset --hard"))
  expect_true(is_dangerous_command("git reset HEAD~1"))
  expect_true(is_dangerous_command("git reset"))
  expect_true(is_dangerous_command("/usr/bin/git reset --hard"))
})

test_that("git rm commands are flagged as dangerous", {
  expect_true(is_dangerous_command("git rm file.txt"))
  expect_true(is_dangerous_command("git rm"))
})

test_that("git push with force flags is dangerous", {
  expect_true(is_dangerous_command("git push --force"))
  expect_true(is_dangerous_command("git push -f"))
  expect_true(is_dangerous_command("git push origin main --force"))
  expect_true(is_dangerous_command("git push --force origin main"))
  expect_false(is_dangerous_command("git push"))
  expect_false(is_dangerous_command("git push origin main"))
})

test_that("git clean with -f or -d flags is dangerous", {
  expect_true(is_dangerous_command("git clean -fd"))
  expect_true(is_dangerous_command("git clean -df"))
  expect_true(is_dangerous_command("git clean -f"))
  expect_true(is_dangerous_command("git clean -fx"))
  expect_true(is_dangerous_command("git clean -d"))
  expect_true(is_dangerous_command("git clean -dx"))
  expect_false(is_dangerous_command("git clean -n"))
  expect_false(is_dangerous_command("git clean --dry-run"))
})

test_that("safe git commands are not flagged as dangerous", {
  expect_false(is_dangerous_command("git status"))
  expect_false(is_dangerous_command("git log"))
  expect_false(is_dangerous_command("git diff"))
  expect_false(is_dangerous_command("git branch"))
  expect_false(is_dangerous_command("git add ."))
  expect_false(is_dangerous_command("git commit -m 'message'"))
  expect_false(is_dangerous_command("/usr/bin/git status"))
  expect_false(is_dangerous_command("git"))
})

test_that("rm with force flags is dangerous", {
  expect_true(is_dangerous_command("rm -rf /path/to/dir"))
  expect_true(is_dangerous_command("rm -f file.txt"))
  expect_true(is_dangerous_command("rm -Rf dir"))
  expect_true(is_dangerous_command("rm -fR dir"))
  expect_true(is_dangerous_command("rm -F file"))
  expect_true(is_dangerous_command("rm -RF dir"))
  expect_false(is_dangerous_command("rm file.txt"))
  expect_false(is_dangerous_command("rm -i file.txt"))
})

test_that("sudo wraps dangerous command detection", {
  expect_true(is_dangerous_command("sudo rm -rf /"))
  expect_true(is_dangerous_command("sudo git reset --hard"))
  expect_false(is_dangerous_command("sudo apt-get update"))
  expect_false(is_dangerous_command("sudo systemctl restart nginx"))
})

test_that("shell wrappers detect embedded dangerous commands", {
  expect_true(is_dangerous_command("bash -c 'git reset --hard'"))
  expect_true(is_dangerous_command("bash -lc 'rm -rf /tmp/stuff'"))
  expect_true(is_dangerous_command("sh -c 'git rm file.txt'"))
  expect_true(is_dangerous_command("bash -c \"git push --force\""))
  expect_false(is_dangerous_command("bash -c 'git status'"))
  expect_false(is_dangerous_command("bash -lc 'ls -la'"))
  expect_false(is_dangerous_command("sh -c 'echo hello'"))
})

test_that("safe commands and edge cases are not flagged", {
  expect_false(is_dangerous_command("ls -la"))
  expect_false(is_dangerous_command("echo 'hello world'"))
  expect_false(is_dangerous_command("cat file.txt"))
  expect_false(is_dangerous_command("pwd"))
  expect_false(is_dangerous_command("cd /tmp"))
  expect_false(is_dangerous_command(""))
  expect_false(is_dangerous_command("   "))
  expect_false(is_dangerous_command("\t\n"))
  expect_false(is_dangerous_command("cd /tmp && ls"))
})

test_that("parse_command splits and cleans command strings", {
  expect_equal(parse_command("git status"), c("git", "status"))
  expect_equal(parse_command("git commit -m 'message'"), c("git", "commit", "-m", "'message'"))
  expect_equal(parse_command("  ls  -la  "), c("ls", "-la"))
  expect_equal(parse_command(""), character(0))
  expect_equal(parse_command("   "), character(0))
})

test_that("is_shell_wrapper identifies shell command wrappers", {
  expect_true(is_shell_wrapper(c("bash", "-c", "echo")))
  expect_true(is_shell_wrapper(c("sh", "-c", "ls")))
  expect_true(is_shell_wrapper(c("zsh", "-lc", "pwd")))
  expect_true(is_shell_wrapper(c("fish", "-c", "git")))
  expect_true(is_shell_wrapper(c("/usr/bin/bash", "-c", "echo")))
  expect_true(is_shell_wrapper(c("/bin/sh", "-lc", "ls")))
  expect_false(is_shell_wrapper(c("git", "status")))
  expect_false(is_shell_wrapper(c("ls", "-la")))
  expect_false(is_shell_wrapper(c("bash", "script.sh")))
  expect_false(is_shell_wrapper(c("bash", "-e", "command")))
  expect_false(is_shell_wrapper(c("bash")))
  expect_false(is_shell_wrapper(c("bash", "-c")))
})

test_that("extract_shell_command extracts embedded commands", {
  expect_equal(extract_shell_command("bash -c 'git status'"), "git status")
  expect_equal(extract_shell_command("sh -lc \"ls -la\""), "ls -la")
  expect_equal(extract_shell_command("bash -c echo hello"), "echo hello")
  expect_null(extract_shell_command("git status"))
  expect_null(extract_shell_command("bash"))
})

test_that("format_shell_output creates formatted markdown output", {
  result <- format_shell_output("ls -la", "output text", "", 0, "List files")
  expect_match(result, "\\*\\*Command:\\*\\* `ls -la`")
  expect_match(result, "\\*\\*Exit code:\\*\\* 0")

  result <- format_shell_output("echo hello", "hello", "", 0, "Echo")
  expect_match(result, "\\*\\*Output:\\*\\*")
  expect_match(result, "hello")

  result <- format_shell_output("cat missing", "", "file not found", 1, "Cat")
  expect_match(result, "\\*\\*Errors:\\*\\*")
  expect_match(result, "file not found")

  result <- format_shell_output("cmd", "output", "warning", 0, "Command")
  expect_match(result, "\\*\\*Output:\\*\\*")
  expect_match(result, "output")
  expect_match(result, "\\*\\*Errors:\\*\\*")
  expect_match(result, "warning")
})
