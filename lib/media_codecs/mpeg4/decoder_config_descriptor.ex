defmodule MediaCodecs.MPEG4.DecoderConfigDescriptor do
  @moduledoc """
  Module describing DecoderConfigDescriptor (defined in: ISO/IEC 14496-1)
  """

  import MediaCodecs.Helper, only: [base128_varint_decode: 1]

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
    :up_stream,
    :buffer_size_db,
    :max_bitrate,
    :avg_bitrate,
    :decoder_specific_info
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
end
