defmodule TaigaToSlack.NicknamesMatcher do
  @moduledoc """
  Replace nicknames found in the comment with nicknames that match ENV defined nicknames.
  """

  def matching_nicknames(list, acc \\ [])

  def matching_nicknames([nickname | tail], acc) do
    matching_nickname = nickname_from_mix_config(nickname) 
    next_acc =
      case nickname do
        _ when matching_nickname != nil -> ["<@#{matching_nickname}>" | acc]
        "@channel" -> ["<!channel>" | acc]
        _ -> ["#{nickname}" | acc]
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
