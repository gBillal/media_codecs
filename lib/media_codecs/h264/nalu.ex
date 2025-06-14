defmodule MediaCodecs.H264.NALU do
  @doc """
  Struct describing an h264 nalu.
  """

  alias MediaCodecs.H264

  @type t :: %__MODULE__{
          type: H264.nalu_type(),
          content: struct() | nil
        }

  defstruct [:type, :content]
end
