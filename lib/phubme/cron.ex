defmodule Cron do
  use Task
  require Logger

  def start_link(_arg) do
    Task.start_link(&send_batch/0)
  end

  def send_batch() do
    state_pid = Process.whereis(:state)
    receive do
      after
        batch_delay_in_s() * 1000 ->
          persisted_events = State.get(state_pid, :events) || []

          case persisted_events do
            [] -> Logger.info("No taiga events to send to slack")
            _ -> 
              Logger.info("Send #{length(persisted_events)} taiga events to slack")
              persisted_events 
              |> convert_events_to_slack_message
              |> PhubMe.Slack.send_private_message
              State.put(state_pid, :events, [])
          end

          send_batch()
      end
  end

    defp batch_delay_in_s do
        d = Application.fetch_env!(:slack, :batch_delay_in_s)
        case d do
            d when not is_integer(d) -> elem(Integer.parse(d), 0)
            _ -> d
        end
    end
  
    defp convert_events_to_slack_message(delta) do
        delta |> inspect |> Logger.info
        Enum.join(delta, "\n")
    end
end