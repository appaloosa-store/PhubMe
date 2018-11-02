defmodule TaigaToSlack.NicknamesMatcher do
  @moduledoc """
  Replace nicknames found in the comment with nicknames that match ENV defined nicknames.
  """
  def match_nicknames(%IssueComment{nicknames: []}) do
    {:error, "No nicknames found in this message"}
  end

  def match_nicknames(%IssueComment{nicknames: nicknames}=issue_comment) do
    
    %{ issue_comment | nicknames: matching_nicknames(nicknames)}
  end

  def matching_nicknames(list, acc \\ [])

  def matching_nicknames([nickname | tail], acc) do
    next_acc =
      case nickname_from_mix_config(nickname) do
        nil -> ["#{nickname}" | acc]
        matching_nickname -> ["<@#{matching_nickname}>" | acc]
      end
    matching_nicknames(tail, next_acc)
  end

  def matching_nicknames([], acc) do
    Enum.reverse(acc)
  end

  defp nickname_from_mix_config(nickname) do
    System.get_env(String.trim_leading(nickname, "@"))
  end
end
