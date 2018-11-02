use Mix.Config

config :slack,
  api_token: System.get_env("SLACK_API_TOKEN") || "xoxb-7579156***********************omA9yr",
  slack_channel: System.get_env("SLACK_CHANNEL"),
  batch_delay_in_s: System.get_env("BATCH_DELAY_IN_S") || 1800

config :logger,
  backends: [:console],
  compile_time_purge_level: :debug
