This is the skeleton of an R package I would like to write. It will be an agentic R package development assistant in the form of a shiny app; running `side::kick()` will launch a `shinychat::chat_app()`.

Please help me write this package by doing the following:

* [ ] Write a `main.md` file in `inst/agents/`. It should be a btw client definition that only has access to `env`, `session`, `ide`, `web` tools. This is the main agent; use the "What makes Claude Code So Damn Good?" article as inspiration when writing its prompt.
* [ ] Write a `researcher.md` file in `inst/agents/`. That agent should have access to `docs`, `env`, `files`, `search`, and `web` tools.
* [ ] Write a function `side::kick(client = NULL)` that starts up a `shinychat::chat_app()` with the main agent. If a client is provided,
