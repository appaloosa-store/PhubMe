defmodule TaigaUserStoryPayload do
  @enforce_keys [:action, :type, :by, :date, :data]
  defstruct [:action, :type, :by, :date, :data, :change]
end



defmodule TaigaEvent do
  @enforce_keys [:type, :title, :id, :url, :mentionned]

  defstruct [:type, :title, :id, :url, :mentionned]

  @type t() :: %__MODULE__{
          type: String.t(),
          title: String.t(),
          id: String.t(),
          url: String.t(),
          mentionned: [String]
        }

end


defmodule IssueComment do
  @moduledoc """
  Struct that is used just after comment parsed :
  * `comment`: The full github comment
  * `nicknames`: Nicknames in the comment. They will be filtered to exclude no-matching
  nicknames.
  * `sender`: The nickname of the sender
  * `source`: The source of the comment (url)
  """
  defstruct [:comment, :nicknames, :sender, :source]
end