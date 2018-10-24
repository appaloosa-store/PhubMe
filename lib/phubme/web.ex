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
    
    event = tp |> convert_payload_to_event

    persisted_events = State.get(state_pid, :events) || []
    events = persisted_events ++ [event]
    State.put(state_pid, :events, events)
  end

  defp convert_payload_to_event(%TaigaUserStoryPayload{}=payload) do
    mentionned = get_taiga_interesting_fields(payload)

      |> Enum.reduce([], fn(str, acc) -> 
        stringList = String.replace(str, "\n", " ")
        |> String.replace("\t", " ")
        |> String.split(~r{ | }, trim: true)
        stringList ++ acc
        end)
      |> Enum.map(fn(str) -> String.trim(str) end)
      |> Enum.filter(fn(str) -> String.starts_with?(str, "@") end)
    
    %TaigaEvent {
      type: get_event_type(payload),
      title: get_in(payload.data, ["subject"]),
      id: get_in(payload.data, ["ref"]),
      url: "#{get_in(payload.data, ["project", "permalink"])}/us/#{get_in(payload.data, ["ref"])}",
      mentionned: mentionned,
    }
  end

  defp get_event_type(%TaigaUserStoryPayload{}=payload) do 
    action = payload.action

    #Check modified comment
    delete_comment_date = get_in(payload.change, ["delete_comment_date"])
    comment = get_in(payload.change, ["comment"])
    
    #Check modified status
    edit_status = get_in(payload.change, ["diff", "status"])
    
    Logger.info("ACTION " <> action)
    cond do
      action == "create" ->
        "created"
      action == "delete" ->
        "deleted"
      action == "" && edit_status != nil ->
        "status changed"
      action == "change" && delete_comment_date == nil and comment != nil and comment != "" ->
        "commented"
      true ->
        "modified"
    end
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