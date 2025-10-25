## Tool Results with Rich Metadata

When implementing tools that return `ContentToolResult` objects, you can include rich metadata that enhances the user interface without affecting what the LLM sees. This separation allows you to send structured, concise data to the LLM while providing beautiful, formatted displays to the user.

### Architecture Overview

The `ellmer::ContentToolResult` class has these key properties (from `ellmer/R/content.R:256-280`):

```r
ContentToolResult <- new_class(
  "ContentToolResult",
  parent = Content,
  properties = list(
    value = class_any,           # Sent to the LLM
    error = ...,                 # Error information
    extra = class_list,          # NOT sent to LLM - UI metadata only
    request = ...                # Tool request (auto-added)
  )
)
```

**Key insight:** The `value` parameter is what the LLM sees. The `extra` parameter is for everything else—display formatting, raw data storage, debugging information.

### The Display Metadata Structure

When using `shinychat` for rendering, the `extra$display` list supports these fields (from `shinychat/R/contents_shinychat.R:298`):

- **`html`**: Raw HTML content for rich displays
- **`markdown`**: Markdown-formatted text (most common)
- **`text`**: Plain text display
- **`title`**: Custom title for the tool result card
- **`icon`**: Custom icon name
- **`show_request`**: Whether to show request details (default: TRUE)
- **`open`**: Whether to expand by default (default: FALSE)

The rendering logic prefers `html` over `markdown` over `text`, using the first one found (from `shinychat/R/contents_shinychat.R:312-331`):

```r
tool_result_display <- function(content, display = NULL) {
  display <- display %||% content@extra$display

  if (is.list(display)) {
    has_type <- intersect(c("html", "markdown", "text"), names(display))
    if (length(has_type) > 0) {
      value_type <- has_type[1]
      return(list(value = display[[value_type]], value_type = value_type))
    }
  }

  list(value = tool_string(content), value_type = "code")
}
```

### Basic Usage Pattern

The `btw` package provides an excellent wrapper pattern (from `btw/R/tool-result.R:1-11`):

```r
BtwToolResult <- S7::new_class(
  "BtwToolResult",
  parent = ellmer::ContentToolResult
)

btw_tool_result <- function(value, data = NULL, ..., cls = BtwToolResult) {
  cls(
    value = value,
    extra = list(data = data, ...)
  )
}
```

This allows storing the full dataset in `extra$data` without sending it to the LLM. You can then add display metadata via `...`.

### Example 1: Data Frames with Rich Display

From `btw/R/tool-data-frame.R:137-142`, showing how to send JSON to the LLM but display a markdown table to users:

```r
btw_tool_result(
  value = data_frame_md,           # Markdown table for LLM
  data = data_frame,               # Full data frame (not sent to LLM)
  display = list(
    title = "View Data Frame",
    markdown = data_frame_md       # Formatted display
  )
)
```

**Why this works:**
- LLM gets readable markdown that preserves data structure
- `extra$data` preserves the actual data frame object for debugging
- UI shows the same markdown in a nice card with custom title
- Full data frame is never serialized into LLM context

### Example 2: Git Diffs with HTML Titles

From `btw/R/tool-git.R:146-155`, using HTML for rich formatting:

```r
btw_tool_result(
  value,
  display = list(
    markdown = value,
    title = HTML(sprintf(
      "Git Diff%s",
      if (!is.null(ref)) sprintf(" (%s)", ref) else ""
    ))
  )
)
```

The `HTML()` wrapper allows dynamic, formatted titles.

### Example 3: Package Help Topics

From `btw/R/tool-docs.R:70-80`, modifying a result after creation:

```r
ret <- btw_tool_env_describe_data_frame_impl(
  res,
  format = "json",
  max_rows = Inf,
  max_cols = Inf
)
ret@extra$display <- list(
  title = sprintf("{%s} Help Topics", package_name),
  markdown = md_table(res)
)
ret
```

You can create a basic result first, then add display metadata afterward.

### Example 4: Custom Tool Result Classes

For specialized rendering, extend `ContentToolResult` and define custom `contents_shinychat()` methods. From `shinychat/tests/testthat/apps/tool-weather/app-06-tool-custom-result-class.R:13-42`:

```r
WeatherToolResult <- S7::new_class(
  "WeatherToolResult",
  parent = ContentToolResult,
  properties = list(
    location_name = S7::class_character
  )
)

S7::method(contents_shinychat, WeatherToolResult) <- function(content) {
  current <- content@value[1, ]

  bslib::value_box(
    title = content@location_name,
    value = current$skies,
    showcase = bsicons::bs_icon("cloud-sun"),
    full_screen = TRUE,
    sprintf("%s°F (High: %s°F, Low: %s°F)", ...)
  )
}
```

This gives you complete control over how the tool result renders in the UI.

### Data Flow Summary

```
1. Tool function returns ContentToolResult(
     value = <concise LLM response>,
     extra = list(
       data = <full data object>,
       display = list(markdown = <formatted display>, title = ...)
     )
   )

2. ellmer extracts `value` → sends to LLM
   ellmer preserves `extra` → available for downstream use

3. shinychat's contents_shinychat() method:
   - Extracts extra$display
   - Validates structure
   - Renders based on html/markdown/text priority
   - Applies title, icon, and expansion settings

4. User sees rich display, LLM sees concise data
```

### When to Use This Pattern

Use `extra$display` when:

1. **Data is large but needs summarization**: Send summary to LLM, show full data to user
2. **Formatting matters**: Send plain text to LLM, show styled HTML/markdown to user
3. **Different representations needed**: Send JSON to LLM, show table to user
4. **Preserving raw data**: Store original data in `extra$data` for debugging/logging
5. **Custom titles/icons needed**: Enhance UI without affecting LLM understanding

Don't use it when:

- Tool result is already concise and well-formatted
- LLM and user should see identical content
- Simple text response is sufficient

### Best Practices

1. **Always populate `value` first**: This is what the LLM sees and must be useful
2. **Use `extra$data` for preservation**: Store full objects here, not in `value`
3. **Prefer markdown for displays**: Most portable, easiest to read
4. **Use HTML sparingly**: Only when markdown is insufficient
5. **Add meaningful titles**: Help users understand tool results at a glance
6. **Consider expandability**: Use `open = FALSE` for large results

### Common Patterns

**Pattern 1: JSON for LLM, Table for User**
```r
btw_tool_result(
  value = jsonlite::toJSON(data, auto_unbox = TRUE),
  data = data,
  display = list(
    markdown = knitr::kable(data, format = "markdown"),
    title = "Query Results"
  )
)
```

**Pattern 2: Summary for LLM, Details for User**
```r
summary_text <- sprintf("Found %d matches in %d files", n_matches, n_files)
details_md <- paste(detailed_results, collapse = "\n")

btw_tool_result(
  value = summary_text,
  display = list(
    markdown = details_md,
    title = "Search Results",
    open = FALSE  # Collapsed by default
  )
)
```

**Pattern 3: Status Update with Custom Icon**
```r
btw_tool_result(
  value = "Build completed successfully",
  display = list(
    markdown = "✓ Build completed in 3.2 seconds\n\nAll tests passed.",
    title = "Build Status",
    icon = "check-circle"
  )
)
```

### Validation and Error Handling

From `shinychat/R/contents_shinychat.R:275-310`, shinychat validates display metadata:

```r
if (inherits(display, c("html", "shiny.tag", "shiny.tag.list", "htmlwidgets"))) {
  cli::cli_warn(c(
    invalid_display_fmt,
    "i" = "To display HTML content for tool results in {.pkg shinychat},
          create a tool result with {.code extra = list(display = list(html = ...))}."
  ))
  return(list())
}
```

**Key takeaway:** Don't pass HTML objects directly. Wrap them in `list(html = ...)`.

### Debugging Tips

1. Check what the LLM sees: `print(result@value)`
2. Check metadata: `print(result@extra)`
3. Test display: `shinychat:::contents_shinychat(result)`
4. Verify structure: `str(result@extra$display)`

### Reference Implementation

For a complete, production-ready implementation, study the `btw` package's tool implementations:

- `btw/R/tool-result.R`: Base wrapper pattern
- `btw/R/tool-data-frame.R`: Data frame handling
- `btw/R/tool-git.R`: Git status and diffs
- `btw/R/tool-docs.R`: Help documentation display
- `btw/R/tool-docs-news.R`: Custom result classes

These provide battle-tested patterns for common tool result scenarios.
