defmodule MediaCodecs.H265.NALU do
  @doc """
  Struct describing an h265 nalu.
  """

  alias MediaCodecs.H265

  @type t :: %__MODULE__{
          type: H265.nalu_type(),
          nuh_layer_id: non_neg_integer(),
          nuh_temporal_id_plus1: non_neg_integer(),
          content: struct() | nil
        }

  defstruct [:type, :nuh_layer_id, :nuh_temporal_id_plus1, :content]
end
