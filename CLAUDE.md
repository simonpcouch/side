This is an R package implementing an agentic R package development assistant, `side::kick()`.

## Resources

Future AI assistants should read the following documentation help-pages:

* `ellmer::Chat`
* `ellmer::tool()`
* `btw::btw()`
* `btw::btw_tools()`
* `btw::btw_client()`
* `shinychat::chat_app()`
* The `tool-ui` vignette from shinychat

Also, read the files in `R/` and `inst/sandbox/tool_results.md`.

## Testing

Generally, when you're finished wrapping up some change in the UI, the most helpful way to "test" the feature is to write a quick prompt that the user can then run themselves and observe the change. For example, if you make a change that affects the file write UI, you might finish your implementation of the change by writing:

> You can test these changes with the following prompt: "I'm testing out your file write tool. Add a comment above the definition for `swap_write_text_file()` in `R/tool-write_text_file.R`."
