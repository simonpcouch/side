
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `side::kick()`: A coding agent for RStudio

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/side)](https://CRAN.R-project.org/package=side)
<!-- badges: end -->

`side::kick()` is a coding agent for data science in RStudio,
implemented entirely in R. It can interact with your files, talk to your
active R session, and run code.

## Installation

To get started, install with:

``` r
pak::pak("simonpcouch/side")
```

Then, run `side::kick()`. You might place `side::kick()` in your
`.Rprofile` (perhaps with `usethis::edit_r_profile()`) to launch
`side::kick()` every time you start R.

`sick::kick()` is intended for use with RStudio’s *Sidebar*, a
full-height pane that’s currently only available in [RStudio
Dailies](https://dailies.rstudio.com/). Install RStudio, then search for
“Sidebar” in the command palette.

## Features

`side::kick()` can **create and execute plans**, allowing it to take on
long-horizon tasks:

In **plan mode**, `side::kick()` will not write to files or run
arbitrary R / bash code:

`side::kick()` supports **skills**, which are markdown files with
instructions on performing tasks that the agent can choose to load into
content at any time:

`side::kick()` is **model-agnostic**: You can use it with any model
that’s available via [ellmer](https://ellmer.tidyverse.org/)–Anthropic,
OpenAI, Google Gemini, OpenRouter, and even local models are fair game.

------------------------------------------------------------------------

*`side::kick()` is implemented with
[btw](https://posit-dev.github.io/btw/),
[ellmer](https://ellmer.tidyverse.org/), and
[shinychat](https://posit-dev.github.io/shinychat/).*
