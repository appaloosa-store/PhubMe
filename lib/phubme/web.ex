defmodule PhubMe.Web do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :match
  plug :dispatch

  def init(options) do
    {:ok, pid } = State.start_link()
    Process.register(pid, :state)
    
    Application.get_all_env(:slack) 
      |> inspect
      |> Logger.info

    options
  end

  def start_link do
    port = String.to_integer(System.get_env("PORT") || "8080")
    {:ok, _ } = Plug.Adapters.Cowboy.http(PhubMe.Web, [], port: port)
  end

  post "/taiga-to-slack" do
    state = Process.whereis(:state)

    if valid_taiga_user_story_payload?(conn.body_params) do
      handle_taiga_user_story_payload(conn.body_params, state)
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, "ok")
      |> halt
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, "")
      |> halt
    end
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, "")
    |> halt
  end

  
  defp valid_taiga_user_story_payload?(
    %{"action" => _action,
    "type" => "userstory",
    "by" => _by,
    "date" => _date,
    "data" => _data}), do: true

  defp handle_taiga_user_story_payload(body_params, state_pid) do

    tp = %TaigaUserStoryPayload{
      action: get_in(body_params, ["action"]),
      type: get_in(body_params, ["type"]),
      by: get_in(body_params, ["by"]),
      date: get_in(body_params, ["date"]),
      data: get_in(body_params, ["data"]),
      change: get_in(body_params, ["change"]),
    }

    Logger.info("Processing taiga user story payload : \"#{inspect(tp)}\"")
    
    event_string = tp 
      |> convert_payload_to_event
      |> convert_event_to_string

    persisted_events = State.get(state_pid, :events) || []
    events = persisted_events ++ [event_string]
    State.put(state_pid, :events, events)
  end

  defp convert_payload_to_event(%TaigaUserStoryPayload{}=payload) do
    mentionned = get_taiga_interesting_fields(payload)

      |> Enum.reduce([], fn(str, acc) -> 
        stringList = String.replace(str, "\n", " ")
        |> String.replace("\t", " ")
        |> String.split(" ", trim: true)
        stringList ++ acc
        end)
      |> Enum.map(fn(str) -> String.trim(str) end)
      |> Enum.filter(fn(str) -> String.starts_with?(str, "@") end)
    
    %TaigaEvent {
      title: get_in(payload.data, ["subject"]),
      id: get_in(payload.data, ["ref"]),
      url: "#{get_in(payload.data, ["project", "permalink"])}/us/#{get_in(payload.data, ["ref"])}",
      mentionned: mentionned,
      prefix: payload.action
    }
  end

  defp convert_event_to_string(%TaigaEvent{}=event) do 
    event |> inspect |> Logger.info
    slack_nicknames = PhubMe.NicknamesMatcher.matching_nicknames(event.mentionned)

Logger.info(slack_nicknames)
    mentions = 
    case slack_nicknames do
      [] -> nil
      _ -> Enum.join(slack_nicknames, ", ") <> " were mentionned."
    end

    "[#{event.prefix}] <#{event.url}|##{event.id}: #{event.title}>. #{mentions}"
  end



  defp get_taiga_interesting_fields(%TaigaUserStoryPayload{ action: "create"}=payload) do 
    [get_in(payload.data, ["description"])] 
    ++
    get_in(payload.data, ["assigned_users"])
  end

  defp get_taiga_interesting_fields(%TaigaUserStoryPayload{ action: "change"}=payload) do 
    [get_in(payload.change, ["comment"])]
  end
  
  defp get_taiga_interesting_fields(%TaigaUserStoryPayload{}) do 
    []
  end

end