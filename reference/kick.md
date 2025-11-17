# A coding agent for RStudio

`side::kick()` is a coding agent for data science in RStudio,
implemented entirely in R. Think of it something like Claude Code or
Codex; it's situated in your project directory and can use tools to
explore its surroundings. In addition, though, it has tools that allow
it to explore your active R session and run R code in it.

To get started with `side::kick()`, just run the function–it will walk
you through the next steps! \#' See
`vignettes("side", package = "side")` for more on getting started with
`side::kick()`, including choosing a model and customizing behavior.

This function requires RStudio and will not launch in Positron or other
R environments.

## Usage

``` r
kick(
  client = getOption("side.client"),
  ...,
  host = getOption("shiny.host", "127.0.0.1")
)
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
