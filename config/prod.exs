use Mix.Config

config :slack,
  api_token: System.get_env("PHUB_ME_SLACK_API_TOKEN") || "xoxb-7579156***********************omA9yr",
  slack_channel: System.get_env("SLACK_CHANNEL")

config :logger,
  backends: [:console],
  compile_time_purge_level: :info
