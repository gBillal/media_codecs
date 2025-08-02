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

  @doc """
  Serializes the Audio Specific Config into a binary format.
  """
  @spec serialize(t()) :: binary()
  def serialize(config) do
    channels = if config.channels == 8, do: 7, else: config.channels

    <<serialize_object_type(config.object_type)::bitstring,
      serialize_sampling_frequency(config.sampling_frequency)::bitstring, channels::4,
      config.aot_specific_config::bitstring>>
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

  defp serialize_object_type(type) when type >= 32, do: <<31::5, type - 32::6>>
  defp serialize_object_type(type), do: <<type::5>>

  defp serialize_sampling_frequency(sample_rate) do
    if index = sampling_frequency_index(sample_rate),
      do: <<index::4>>,
      else: <<15::4, sample_rate::24>>
  end
end
