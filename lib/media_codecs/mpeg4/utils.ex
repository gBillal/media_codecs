defmodule MediaCodecs.MPEG4.Utils do
  @moduledoc """
  Utilities functions
  """

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

  @reverse_sampling_frequency %{
    96000 => 0,
    88200 => 1,
    64000 => 2,
    48000 => 3,
    44100 => 4,
    32000 => 5,
    24000 => 6,
    22050 => 7,
    16000 => 8,
    12000 => 9,
    11025 => 10,
    8000 => 11,
    7350 => 12
  }

  @doc """
  Returns the sampling frequency index for a given sampling frequency.
  """
  @spec sampling_frequency_index(non_neg_integer()) :: non_neg_integer() | nil
  def sampling_frequency_index(sample_rate), do: @reverse_sampling_frequency[sample_rate]

  @doc """
  Returns the sampling frequency for a given index.
  """
  @spec sampling_frequency_from_index(non_neg_integer()) :: non_neg_integer() | nil
  def sampling_frequency_from_index(index), do: @sampling_frequency[index]

  @doc """
  Returns the channel configuration from channels.
  """
  @spec channel_config(non_neg_integer()) :: non_neg_integer()
  def channel_config(8), do: 7
  def channel_config(channels) when channels in 0..6, do: channels
end
