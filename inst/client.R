cli::cli_alert_info('Welcome to `side::kick()`! You\'ll be redirected back to the console shortly.')

library(btw)
library(ellmer)
library(shinychat)

if (!requireNamespace('side', quietly = TRUE)) {
  stop('side package must be installed')
}

{{client_code}}

client$set_tools(side:::sidekick_tools('{{env_url}}'))

shinychat::chat_app(client)
