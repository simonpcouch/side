
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `side::kick()`: A coding agent for RStudio

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/side)](https://CRAN.R-project.org/package=side)
<!-- badges: end -->

`side::kick()` is a fully-featured coding agent for data science in
RStudio, implemented entirely in R. It can interact with your files,
talk to your active R session, and run code.

<img src="https://gist.github.com/user-attachments/assets/37922191-aaa9-4143-ae36-da79a2f25e06" alt="A screencast of an RStudio session. A script tool-fetch_skill.R is open in the editor. A call to `side::kick()` in the console launches a non-blocking shiny chat app in a full-height viewer pane. The user then pastes a snippet of code into the chat dialog and says 'refactor this into a helper'. After calling multiple tools to locate the code, the chat app proposes two file edits in a git diff-based UI that refactor the code as desired." width="100%" />

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

`side::kick()` can:

- **Use any LLM** supported by
  [ellmer](https://ellmer.tidyverse.org/)–Anthropic, OpenAI, Google
  Gemini, OpenRouter, and even local models are fair game.
- **See your active R session** to explore your computational
  environment.
- **Use tools** to read and write files, run shell commands, and read R
  documentation.
- **Create and execute plans**, allowing it to take on longer-horizon
  tasks.
- **Persist state** across R sessions so that you can close RStudio and
  come back to a chat later.
- Respond to **interrupts** so that you can stop execution and reroute
  the agent.
- Read **skills**, markdown files that describe how to carry out a given
  task in the way you need it to.

------------------------------------------------------------------------

*`side::kick()` is implemented with
[btw](https://posit-dev.github.io/btw/),
[ellmer](https://ellmer.tidyverse.org/), and
[shinychat](https://posit-dev.github.io/shinychat/).*
