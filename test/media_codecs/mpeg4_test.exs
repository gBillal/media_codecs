defmodule MediaCodecs.MPEG4Test do
  use ExUnit.Case, async: true

  alias MediaCodecs.MPEG4
  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, ESDescriptor}

  test "parse descriptors" do
    descriptor_data =
      <<3, 128, 128, 128, 37, 0, 0, 4, 4, 128, 128, 128, 23, 64, 21, 0, 7, 208, 0, 0, 0, 0, 0, 0,
        0, 0, 5, 128, 128, 128, 5, 7, 128, 15, 160, 8, 6, 128, 128, 128, 1, 2>>

    assert [
             %ESDescriptor{
               es_id: 0,
               stream_dependence_flag: false,
               url_flag: false,
               ocr_stream_flag: false,
               stream_priority: 4,
               depends_on_es_id: 0,
               url: nil,
               ocr_es_id: 0,
               dec_config_descr: %DecoderConfigDescriptor{
                 object_type_indication: 64,
                 stream_type: 5,
                 up_stream: false,
                 buffer_size_db: 2000,
                 max_bitrate: 0,
                 avg_bitrate: 0,
                 decoder_specific_info: <<7, 128, 15, 160, 8>>
               }
             }
           ] = MPEG4.parse_descriptors(descriptor_data)
  end

  test "Serialize DecoderConfigDescriptor" do
    descriptor = %DecoderConfigDescriptor{
      object_type_indication: 64,
      stream_type: 5,
      up_stream: false,
      buffer_size_db: 2000,
      max_bitrate: 0,
      avg_bitrate: 0,
      decoder_specific_info: <<7, 128, 15, 160, 8>>
    }

    expected = <<4, 20, 64, 21, 0, 7, 208, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 7, 128, 15, 160, 8>>

    assert DecoderConfigDescriptor.serialize(descriptor) == expected
    assert [^descriptor] = MPEG4.parse_descriptors(expected)
  end

  test "Serialize ESDecriptor" do
    descriptor = %ESDescriptor{
      es_id: 0,
      stream_dependence_flag: false,
      url_flag: false,
      ocr_stream_flag: false,
      stream_priority: 4,
      depends_on_es_id: 0,
      url: nil,
      ocr_es_id: 0,
      dec_config_descr: %DecoderConfigDescriptor{
        object_type_indication: 64,
        stream_type: 5,
        up_stream: false,
        buffer_size_db: 2000,
        max_bitrate: 0,
        avg_bitrate: 0,
        decoder_specific_info: <<7, 128, 15, 160, 8>>
      }
    }

    expected =
      <<3, 25, 0, 0, 4, 4, 20, 64, 21, 0, 7, 208, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 7, 128, 15, 160,
        8>>

    assert ESDescriptor.serialize(descriptor) == expected
    assert [^descriptor] = MPEG4.parse_descriptors(expected)
  end
end
