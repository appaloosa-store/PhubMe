defmodule TaigaUserStoryPayload do
  @enforce_keys [:action, :type, :by, :date, :data]
  defstruct [:action, :type, :by, :date, :data, :change]
end



defmodule TaigaEvent do
  @enforce_keys [:type, :title, :id, :url, :by, :mentionned]

  defstruct [:type, :title, :id, :url, :by, :mentionned]

  @type t() :: %__MODULE__{
          type: String.t(),
          title: String.t(),
          id: String.t(),
          url: String.t(),
          by: String.t(),
          mentionned: [String]
        }

end