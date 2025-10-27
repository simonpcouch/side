test_that("safe git commands are not flagged as dangerous", {
  expect_false(is_dangerous_command("git status"))
  expect_false(is_dangerous_command("git log"))
  expect_false(is_dangerous_command("git diff"))
  expect_false(is_dangerous_command("git branch"))
  expect_false(is_dangerous_command("git add ."))
  expect_false(is_dangerous_command("git commit -m 'message'"))
  expect_false(is_dangerous_command("git push"))
  expect_false(is_dangerous_command("/usr/bin/git status"))
})

test_that("dangerous git commands are flagged", {
  expect_true(is_dangerous_command("git reset --hard"))
  expect_true(is_dangerous_command("git reset HEAD~1"))
  expect_true(is_dangerous_command("git rm file.txt"))
  expect_true(is_dangerous_command("git push --force"))
  expect_true(is_dangerous_command("git push -f"))
  expect_true(is_dangerous_command("git clean -fd"))
  expect_true(is_dangerous_command("git clean -df"))
  expect_true(is_dangerous_command("/usr/bin/git reset --hard"))
})

test_that("dangerous rm commands are flagged", {
  expect_true(is_dangerous_command("rm -rf /path/to/dir"))
  expect_true(is_dangerous_command("rm -f file.txt"))
  expect_true(is_dangerous_command("rm -Rf dir"))
  expect_true(is_dangerous_command("rm -fR dir"))
})

test_that("safe rm commands are not flagged as dangerous", {
  expect_false(is_dangerous_command("rm file.txt"))
  expect_false(is_dangerous_command("rm -i file.txt"))
})

test_that("sudo with dangerous commands is flagged", {
  expect_true(is_dangerous_command("sudo rm -rf /"))
  expect_true(is_dangerous_command("sudo git reset --hard"))
})

test_that("sudo with safe commands is not flagged", {
  expect_false(is_dangerous_command("sudo apt-get update"))
  expect_false(is_dangerous_command("sudo systemctl restart nginx"))
})

test_that("shell-wrapped dangerous commands are detected", {
  expect_true(is_dangerous_command("bash -c 'git reset --hard'"))
  expect_true(is_dangerous_command("bash -lc 'rm -rf /tmp/stuff'"))
  expect_true(is_dangerous_command("sh -c 'git rm file.txt'"))
  expect_true(is_dangerous_command("bash -c \"git push --force\""))
})

test_that("shell-wrapped safe commands are not flagged", {
  expect_false(is_dangerous_command("bash -c 'git status'"))
  expect_false(is_dangerous_command("bash -lc 'ls -la'"))
  expect_false(is_dangerous_command("sh -c 'echo hello'"))
})

test_that("non-dangerous commands are not flagged", {
  expect_false(is_dangerous_command("ls -la"))
  expect_false(is_dangerous_command("echo 'hello world'"))
  expect_false(is_dangerous_command("cat file.txt"))
  expect_false(is_dangerous_command("pwd"))
  expect_false(is_dangerous_command("cd /tmp"))
})

test_that("empty or whitespace-only commands are not flagged", {
  expect_false(is_dangerous_command(""))
  expect_false(is_dangerous_command("   "))
  expect_false(is_dangerous_command("\t\n"))
})
