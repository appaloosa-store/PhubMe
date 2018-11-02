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
              |> group_events_by_story
              |> convert_events_to_slack_message
              |> TaigaToSlack.Slack.send_private_message
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

    defp convert_events_to_slack_message(events_map) do

        Logger.info("Map" <> inspect(events_map))
        events_map
            |> Map.keys
            |> Enum.map(
                fn(story_id) -> 
                    #Get the story title
                    title = get_story_title(story_id, events_map)

                    #Get the events summary
                    story_events = events_map[story_id]
                    summary = Enum.map(story_events, fn(e) -> convert_event_to_string(e) end)
                        |> merge_contiguous_duplicates
                        |> Enum.join("\n")
                    
                    "#{title}\n#{summary}"
                end
                )
            |> Enum.join("\n\n")
    end

    def merge_contiguous_duplicates(story_events) do
        Enum.reduce(story_events, [], fn(e, array) -> 
            last_event = List.last(array)
            if last_event != e do array ++ [e] else array end
        end)
    end

    defp get_story_title(story_id, events_map) do
        Logger.info(inspect(events_map[story_id]))
        last_event = Enum.fetch!(events_map[story_id],-1)
        "<#{last_event.url}|##{last_event.id}: #{last_event.title}>"
    end

    defp convert_event_to_string(event) do 
        event |> inspect |> Logger.info
        slack_nicknames = TaigaToSlack.NicknamesMatcher.matching_nicknames(event.mentionned)

        Logger.info(slack_nicknames)
        mentions = 
        case slack_nicknames do
        [] -> nil
        _ -> "- #{Enum.join(slack_nicknames, ", ")} mentionned."
        end

        "[#{event.type}] by #{event.by} #{mentions}"
    end

    defp group_events_by_story(events) do
        events
        |> Enum.reduce(%{}, fn(e, map) -> Map.merge(map, %{e.id => [e]}, fn _k, v1, v2 ->
  v1 ++ v2 end) end)
    end

end