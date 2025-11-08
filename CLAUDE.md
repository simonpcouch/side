# NA

This is an R package implementing an agentic R package development
assistant,
[`side::kick()`](https://simonpcouch.github.io/side/reference/kick.md).

## Resources

Future AI assistants should read the following documentation help-pages:

- [`ellmer::Chat`](https://ellmer.tidyverse.org/reference/Chat.html)
- [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
- [`btw::btw()`](https://posit-dev.github.io/btw/reference/btw.html)
- [`btw::btw_tools()`](https://posit-dev.github.io/btw/reference/btw_tools.html)
- [`btw::btw_client()`](https://posit-dev.github.io/btw/reference/btw_client.html)
- [`shinychat::chat_app()`](https://posit-dev.github.io/shinychat/r/reference/chat_app.html)

Also, read the files in `R/`, `inst/sandbox/tool_results.md`, and
`inst/sandbox/shinychat/pkg-r/vignettes/articles/tool-ui.Rmd`.

You have the source code for the ellmer, shinychat, and btw repositories
in subdirectories of `inst/sandbox/`. Use the source files as a
reference when needed.

## Testing

Generally, when you’re finished wrapping up some change in the UI, the
most helpful way to “test” the feature is to write a quick prompt that
the user can then run themselves and observe the change. For example, if
you make a change that affects the file write UI, you might finish your
implementation of the change by writing:

> You can test these changes with the following prompt: “I’m testing out
> your file write tool. Add a comment above the definition for
> `swap_write_text_file()` in `R/tool-write_text_file.R`.”
