defmodule MediaCodecs.MPEG4.AudioSpecificConfig do
  @moduledoc """
  Module defining the Audio Specific Config for MPEG-4 audio codecs.
  """

  @type t :: %__MODULE__{
          object_type: integer(),
          sampling_frequency: integer(),
          channels: 0..8,
          aot_specific_config: bitstring()
        }

  @sampling_frequency %{
    0 => 96000,
    1 => 88200,
    2 => 64000,
    3 => 48000,
    4 => 44100,
    5 => 32000,
    6 => 24000,
    7 => 22050,
    8 => 16000,
    9 => 12000,
    10 => 11025,
    11 => 8000,
    12 => 7350
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
    {@sampling_frequency[frequency_index], rest}
  end
end
