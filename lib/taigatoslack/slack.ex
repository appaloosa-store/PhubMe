defmodule TaigaToSlack.Slack do
  require Logger
  @moduledoc """
  Send message to slack.
  """

  def send_private_message({:error, error_message}) do
    Logger.error("[TaigaToSlack][Error] " <> error_message)
  end

  def send_private_message(message) do
    channel = slack_channel()
    Logger.info("Sending message on #{slack_channel()}")
    case Slack.Web.Chat.post_message(channel, message, %{token: slack_token()}) do
      %{"error" => "invalid_auth"} -> invalid_slack_auth_message()
      %{"ok" => false, "error" => "no_channel_found"} -> no_matching_channel_message(channel)
      %{"ok" => false, "error" => "account_inactive"} -> account_inactive()
      _ -> matching_channel_message()
    end
  end

  defp slack_token do
    Application.fetch_env!(:slack, :api_token)
  end

  defp slack_channel do
    Application.fetch_env!(:slack, :slack_channel)
  end

  defp invalid_slack_auth_message do
    raise "Failed to connect. Are you sure you add correct SLACK_API_TOKEN?"
  end

  defp no_matching_channel_message(nick) do
    Logger.info("Not matching channel with the nickname " <>
                nick <> ". Are you sure it exists?")
  end

  defp matching_channel_message do
    Logger.info("Matching channel found.")
  end

  defp account_inactive do
    Logger.info("Slack bot account seems unactivated")
  end
end
