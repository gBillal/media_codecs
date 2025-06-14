defmodule MediaCodecs.H265.NALU do
  @doc """
  Struct describing an h265 nalu.
  """

  alias MediaCodecs.H265

  @type t :: %__MODULE__{
          type: H265.nalu_type(),
          content: struct() | nil
        }

  defstruct [:type, :content]
end
