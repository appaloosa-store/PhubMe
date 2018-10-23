use Mix.Config

config :slack,
  api_token: System.get_env("PHUBME_SLACK_TOKEN") || "xoxp-2318107249-351980448786-461530527713-4829f547bba10a7894c3096b12ffbe0d",
  slack_channel: System.get_env("SLACK_CHANNEL")

config :logger,
  backends: [:console],
  compile_time_purge_level: :debug
