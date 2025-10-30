# validate_write_text_file_syntax errors informatively with invalid input

    Code
      validate_write_text_file_syntax(path = "test.R", insert_line = 1, new_str = "new text",
        old_str = "old text")
    Condition
      Error:
      ! Cannot use both str_replace mode (old_str/new_str) and insert mode (insert_line/new_str) at the same time.

---

    Code
      validate_write_text_file_syntax(path = "test.R", insert_line = NULL, new_str = "new text",
        old_str = NULL)
    Condition
      Error:
      ! Must provide either (old_str + new_str) for replacement or (insert_line + new_str) for insertion.

---

    Code
      validate_write_text_file_syntax(path = "test.R", insert_line = NULL, new_str = NULL,
        old_str = NULL)
    Condition
      Error:
      ! Must provide either (old_str + new_str) for replacement or (insert_line + new_str) for insertion.

