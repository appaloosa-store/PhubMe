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
    State.put(pid, :last_message_date, DateTime.utc_now())

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

  defp handle_taiga_user_story_payload(body_params, state) do

    tp = %TaigaUserStoryPayload{
      action: get_in(body_params, ["action"]),
      type: get_in(body_params, ["type"]),
      by: get_in(body_params, ["by"]),
      date: get_in(body_params, ["date"]),
      data: get_in(body_params, ["data"]),
      change: get_in(body_params, ["change"]),
    }

    Logger.info("Processing taiga user story payload : \"#{inspect(tp)}\"")
    
    #Fetch delta from the persisted state
    persisted_events = State.get(state, :events) || []
    now = DateTime.utc_now()
    last_message_date = State.get(state, :last_message_date) || DateTime.utc_now()

    event_string = tp 
      |> convert_payload_to_event
      |> convert_event_to_string

    events = persisted_events ++ [event_string]
    
    Logger.info(DateTime.diff(now, last_message_date))

    if DateTime.diff(now, last_message_date) > batch_delay_in_s() do
      events 
        |> convert_events_to_slack_message
        |> PhubMe.Slack.send_private_message
      State.put(state, :events, [])
      State.put(state, :last_message_date, now)
    else
      State.put(state, :events, events)
    end
  end

  defp convert_payload_to_event(%TaigaUserStoryPayload{}=payload) do
    mentionned = get_taiga_interesting_fields(payload)
      |> Enum.reduce([], fn(str, acc) -> String.split(str, " ") ++ acc end)
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
    "[#{event.prefix}] <#{event.url}|##{event.id}: #{event.title}>. #{Enum.join(slack_nicknames, ", ")} mentionned"
  end

  defp convert_events_to_slack_message(delta) do
    delta |> inspect |> Logger.info

    """
    Last updates from Taiga :
    \n
    #{Enum.join(delta, "\n")}
    """
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

  defp batch_delay_in_s do
    Application.fetch_env!(:slack, :batch_delay_in_s)
  end

end