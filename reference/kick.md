# A coding agent for RStudio

`side::kick()` is a coding agent for data science in RStudio,
implemented entirely in R. Think of it something like Claude Code or
Codex; it's situated in your project directory and can use tools to
explore its surroundings. In addition, though, it has tools that allow
it to explore your active R session and run R code in it.

To get started with `side::kick()`, just run the function–it will walk
you through the next steps!

This function requires RStudio and will not launch in Positron or other
R environments.

## Usage

``` r
kick(client = NULL, ..., host = getOption("shiny.host", "127.0.0.1"))
```

## Arguments

- client:

  An [ellmer::Chat](https://ellmer.tidyverse.org/reference/Chat.html)
  client to power the `side::kick()` app. See the "Choosing a model"
  section below to learn more.

- ...:

  Currently ignored.

- host:

  A character string specifying the host on which to run the app.
  Defaults to the value of `getOption("shiny.host", "127.0.0.1")`.

## Value

Launches a shiny application as a background job in RStudio. The
application is displayed in the RStudio viewer pane and this function
will return after the application is launched successfully.

## Choosing a model

`side::kick()` can use any model provider available in
[`ellmer::chat()`](https://ellmer.tidyverse.org/reference/chat-any.html)
to power the application. The app uses the `side.client` option (or the
`side::kick(client)` argument if you prefer) to configure the ellmer
Chat that powers the app; that option can be set to any
[ellmer::Chat](https://ellmer.tidyverse.org/reference/Chat.html) object.

When you call `kick()` without a client configured, a setup flow will
guide you through selecting a model. The setup flow will:

1.  Check which providers are available based on your API keys (stored
    in environment variables) from a preferred subset of providers.

2.  Allow you to select from available providers.

3.  Ask if you want to save this configuration a) just for the current R
    session or b) in this *and* future R sessions (by adding it to your
    `.Rprofile`).

You can also configure a client manually by setting the `side.client`
option:

    # For the current session only
    options(side.client = ellmer::chat_anthropic(model = "claude-sonnet-4-5"))

    # In .Rprofile for all sessions
    usethis::edit_r_profile()
    # Then add:
    options(side.client = ellmer::chat_anthropic(model = "claude-sonnet-4-5"))

**`side::kick()` was developed with Claude Sonnet 4.5 in mind**; use
that model for best results. That said, any frontier non-thinking (or
quickly-thinking) model like GPT 4.1 or Gemini 2.5 Pro will do fine. As
of late 2025, I do not recommend using local (e.g.
[`ellmer::chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html))
models, but you can give it a try!

## Customizing behavior

You can customize the assistant's behavior for your project by creating
a `CLAUDE.md`, `btw.md`, `llms.txt`, or `AGENTS.md` file in your project
directory. The assistant will read the first file it finds (in that
order) and include its contents in the system prompt, allowing you to
provide project-specific instructions, coding conventions, or context.
