defmodule MediaCodecs.MPEG4.DecoderConfigDescriptor do
  @moduledoc """
  Module describing DecoderConfigDescriptor (defined in: ISO/IEC 14496-1)
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          object_type_indication: non_neg_integer(),
          stream_type: non_neg_integer(),
          up_stream: boolean(),
          buffer_size_db: non_neg_integer(),
          max_bitrate: non_neg_integer(),
          avg_bitrate: non_neg_integer(),
          decoder_specific_info: binary()
        }

  defstruct [
    :object_type_indication,
    :stream_type,
    :decoder_specific_info,
    up_stream: false,
    buffer_size_db: 0,
    max_bitrate: 0,
    avg_bitrate: 0
  ]

  @doc """
  Parses the binary into a DecoderConfigDescriptor struct.
  """
  @spec parse(binary()) :: t()
  def parse(
        <<object_type_indication::8, stream_type::6, up_stream::1, _::1, buffer_size_db::24,
          max_bitrate::32, avg_bitrate::32, 0x05, rest::binary>>
      ) do
    {section_size, rest} = base128_varint_decode(rest)
    <<decoder_specific_info::binary-size(section_size), _::binary>> = rest

    %__MODULE__{
      object_type_indication: object_type_indication,
      stream_type: stream_type,
      up_stream: up_stream == 1,
      buffer_size_db: buffer_size_db,
      max_bitrate: max_bitrate,
      avg_bitrate: avg_bitrate,
      decoder_specific_info: decoder_specific_info
    }
  end

  @doc """
  Serializes the DecoderConfigDescriptor struct into a binary format.
  """
  @spec serialize(t()) :: binary()
  def serialize(%__MODULE__{} = descriptor) do
    decoder_specific_config = serialize_decoder_specific_info(descriptor.decoder_specific_info)

    <<0x04>> <>
      base128_varint_encode(13 + byte_size(decoder_specific_config)) <>
      <<descriptor.object_type_indication, descriptor.stream_type::6,
        bool_to_int(descriptor.up_stream)::1, 1::1, descriptor.buffer_size_db::24,
        descriptor.max_bitrate::32,
        descriptor.avg_bitrate::32>> <>
      serialize_decoder_specific_info(descriptor.decoder_specific_info)
  end

  defp serialize_decoder_specific_info(nil), do: <<>>

  defp serialize_decoder_specific_info(config) do
    <<0x05>> <> base128_varint_encode(byte_size(config)) <> config
  end
end
