defmodule MediaCodecs.MPEG4.ADTS do
  @moduledoc """
  Module for parsing and serializing ADTS (Audio Data Transport Stream) packets.
  """

  import MediaCodecs.MPEG4.Utils

  @type t :: %__MODULE__{
          audio_object_type: non_neg_integer(),
          sampling_frequency: non_neg_integer(),
          channels: 0..8,
          frames_count: non_neg_integer(),
          frames: binary()
        }

  defstruct [:audio_object_type, :sampling_frequency, :channels, :frames, frames_count: 1]

  @doc """
  Parses an ADTS packet from a binary stream.

  This function returns:
    * `{:ok, packet, unprocessed}` if the packet is successfully parsed with `unprocessed` as the remaining unprocessed binary.
    * `:more` if more data is needed to complete the parsing.
    * `{:error, :invalid_packet}` if the packet is invalid or cannot be parsed.
  """
  @spec parse(binary()) :: {:ok, t(), unprocessed :: binary()} | :more | {:error, :invalid_packet}
  def parse(adts_stream) do
    with {:ok, {audio_object_type, sample_rate, channels, frames_count, frames_length}, rest} <-
           parse_header(adts_stream),
         {:ok, frames, rest} <- parse_frames(frames_length, rest) do
      {:ok,
       %__MODULE__{
         audio_object_type: audio_object_type,
         sampling_frequency: sample_rate,
         channels: channels,
         frames: frames,
         frames_count: frames_count + 1
       }, rest}
    end
  end

  @doc """
  Serializes an ADTS packet into a binary.
  """
  @spec serialize(t()) :: binary()
  def serialize(%__MODULE__{} = packet) do
    packet_size = 7 + byte_size(packet.frames)

    <<0xFFF::12, 0::1, 0::2, 1::1, packet.audio_object_type - 1::2,
      sampling_frequency_index(packet.sampling_frequency)::4, 0::1,
      channel_config(packet.channels)::3, 0::4, packet_size::13, 0x7FF::11,
      packet.frames_count - 1::2, packet.frames::binary>>
  end

  defp parse_header(data) when byte_size(data) < 7, do: :more

  defp parse_header(
         <<0xFFF::12, _mpeg_version::1, _layer::2, protection::1, profile::2,
           sampling_frequency::4, _private::1, channel_config::3, _::4, frames_length::13,
           _buffer_fullness::11, frames_count::2, rest::binary>>
       ) do
    with {:ok, rest} <- discard_crc(protection, rest),
         sample_rate when not is_nil(sample_rate) <-
           sampling_frequency_from_index(sampling_frequency) do
      header_size = 9 - protection * 2

      {:ok,
       {profile + 1, sample_rate, channels_from_config(channel_config), frames_count,
        frames_length - header_size}, rest}
    else
      nil -> {:error, :invalid_packet}
      error -> error
    end
  end

  defp parse_header(_data), do: {:error, :invalid_packet}

  defp discard_crc(0, data) when byte_size(data) < 2, do: :more
  defp discard_crc(0, <<_crc::16, rest::binary>>), do: {:ok, rest}
  defp discard_crc(1, data), do: {:ok, data}

  defp channels_from_config(7), do: 8
  defp channels_from_config(config), do: config

  defp parse_frames(frames_length, data) do
    case data do
      <<frames::binary-size(frames_length), rest::binary>> -> {:ok, frames, rest}
      _data -> :more
    end
  end
end
