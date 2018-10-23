defmodule PhubMe.Web do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:json], json_decoder: Poison
  plug :match
  plug :dispatch

  def init(options) do
    options
  end

  def start_link do
    port = String.to_integer(System.get_env("PORT") || "8080")
    {:ok, _ } = Plug.Adapters.Cowboy.http(PhubMe.Web, [], port: port)
  end

  post "/taiga-to-slack" do
    #{:ok, queue } = PhubMe.Queue.start_link(:personal_queue)
    #PhubMe.Queue.put(:personal_queue, "KEY", "check emails")

    #PhubMe.Queue.get(:personal_queue, "VALUE") |> Logger.info

    # Verify HMAC in header : X-TAIGA-WEBHOOK-SIGNATURE
   
    # Extract Taiga payload

    # Store data

    if valid_taiga_user_story_payload?(conn.body_params) do
      handle_taiga_user_story_payload(conn.body_params)
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

  #defp valid_github_payload?(%{"hook" => _hook}, ["ping"]), do: true
  #defp valid_github_payload?(_body_params, _req_header), do: false

  defp handle_taiga_user_story_payload(body_params) do

    tp = %TaigaUserStoryPayload{
      action: get_in(body_params, ["action"]),
      type: get_in(body_params, ["type"]),
      by: get_in(body_params, ["by"]),
      date: get_in(body_params, ["date"]),
      data: get_in(body_params, ["data"]),
      change: get_in(body_params, ["change"]),
    }

    Logger.info("Processing taiga user story payload : \"#{inspect(tp)}\"")
    
    #TODO : fetch delta from an Agent
    delta = []
    
    event_string = tp |> convert_payload_to_event |> convert_event_to_string

    slackMessage = delta ++ [event_string]
      |> convert_delta_to_slack_message

    PhubMe.Slack.send_private_message("@benjamin.orsini616", slackMessage)

    #PhubMe.CommentParser.process_comment(body_params)
    #|> PhubMe.NicknamesMatcher.match_nicknames
    #|> PhubMe.Slack.send_private_message
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

  defp convert_delta_to_slack_message(delta) do
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

end