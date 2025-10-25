tool_icon <- local({
  icons <- list()
  function(name) {
    if (!is.null(icons[[name]])) {
      return(icons[[name]])
    }

    icon <- htmltools::HTML(readLines(
      system.file("icons", paste0(name, ".svg"), package = "side"),
      warn = FALSE
    ))
    icons[[name]] <<- icon
    return(icon)
  }
})
