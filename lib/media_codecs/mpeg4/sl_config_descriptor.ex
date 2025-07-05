defmodule MediaCodecs.MPEG4.SLConfigDescriptor do
  @moduledoc """
  Module describing SLConfigDescriptor (defined in: ISO/IEC 14496-1)
  """

  @type t :: %__MODULE__{
          predefined: non_neg_integer()
        }

  defstruct [:predefined]

  @doc """
  Parses the binary into a SLConfigDescriptor struct.
  """
  @spec parse(binary()) :: t()
  def parse(<<predefined::8, _rest::binary>>) do
    %__MODULE__{predefined: predefined}
  end

  @doc """
  Serializes the SLConfigDescriptor struct into a binary format.
  """
  @spec serialize(t()) :: binary()
  def serialize(%__MODULE__{predefined: predefined}) do
    <<0x06, 0x01, predefined::8>>
  end
end
