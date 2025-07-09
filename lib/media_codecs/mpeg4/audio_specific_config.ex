defmodule MediaCodecs.MPEG4.AudioSpecificConfig do
  @moduledoc """
  Module defining the Audio Specific Config for MPEG-4 audio codecs.
  """

  import MediaCodecs.MPEG4.Utils

  @type t :: %__MODULE__{
          object_type: integer(),
          sampling_frequency: integer(),
          channels: 0..8,
          aot_specific_config: bitstring()
        }

  defstruct [:object_type, :sampling_frequency, :channels, :aot_specific_config]

  @doc """
  Parses the Audio Specific Config from a binary data.
  """
  @spec parse(binary()) :: t()
  def parse(data) do
    {object_type, rest} = object_type(data)
    {sampling_frequency, rest} = sampling_frequency(rest)
    <<channel_config::4, aot_specific_config::bitstring>> = rest

    %__MODULE__{
      object_type: object_type,
      sampling_frequency: sampling_frequency,
      channels: if(channel_config == 7, do: 8, else: channel_config),
      aot_specific_config: aot_specific_config
    }
  end

  defp object_type(<<31::5, object_type::6, rest::bitstring>>) do
    {object_type + 32, rest}
  end

  defp object_type(<<object_type::5, rest::bitstring>>) do
    {object_type, rest}
  end

  defp sampling_frequency(<<15::4, sampling_frequency::24, rest::bitstring>>) do
    {sampling_frequency, rest}
  end

  defp sampling_frequency(<<frequency_index::4, rest::bitstring>>) do
    {sampling_frequency_from_index(frequency_index), rest}
  end
end
