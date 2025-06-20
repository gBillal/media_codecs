defmodule MediaCodecs.H264.NALU do
  @doc """
  Struct describing an h264 nalu.
  """

  alias MediaCodecs.H264

  @type t :: %__MODULE__{
          type: H264.nalu_type(),
          nal_ref_idc: non_neg_integer(),
          content: struct() | nil
        }

  defstruct [:type, :nal_ref_idc, :content]
end
