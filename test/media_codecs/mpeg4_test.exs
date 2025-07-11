defmodule MediaCodecs.MPEG4Test do
  use ExUnit.Case, async: true

  alias MediaCodecs.MPEG4
  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, ESDescriptor, SLConfigDescriptor}

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
      },
      sl_config_descr: %SLConfigDescriptor{predefined: 2}
    }

    expected =
      <<3, 28, 0, 0, 4, 4, 20, 64, 21, 0, 7, 208, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 7, 128, 15, 160,
        8, 6, 1, 2>>

    assert ESDescriptor.serialize(descriptor) == expected
    assert [^descriptor] = MPEG4.parse_descriptors(expected)
  end

  describe "parse_adts_stream/1" do
    test "parse adts stream" do
      stream =
        <<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3,
          4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 255, 241, 80, 128, 1, 159, 252, 1>>

      assert {:ok, packets, unprocessed} = MPEG4.parse_adts_stream(stream)
      assert length(packets) == 3
      assert <<255, 241, 80, 128, 1, 159, 252, 1>> = unprocessed
    end

    test "parse invalid stream" do
      stream =
        <<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 254, 241, 80, 128, 1, 159, 252, 1, 2, 3,
          4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5>>

      assert {:error, :invalid_packet} = MPEG4.parse_adts_stream(stream)
    end
  end

  describe "parse_adts_stream!/1" do
    test "parse adts stream" do
      stream =
        <<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3,
          4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 255, 241, 80, 128, 1, 159, 252, 1>>

      assert {packets, unprocessed} = MPEG4.parse_adts_stream!(stream)
      assert length(packets) == 3
      assert <<255, 241, 80, 128, 1, 159, 252, 1>> = unprocessed
    end

    test "parse invalid stream" do
      stream =
        <<255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5, 254, 241, 80, 128, 1, 159, 252, 1, 2, 3,
          4, 5, 255, 241, 80, 128, 1, 159, 252, 1, 2, 3, 4, 5>>

      assert_raise RuntimeError, "Invalid ADTS packet encountered", fn ->
        MPEG4.parse_adts_stream!(stream)
      end
    end
  end
end
