defmodule MediaCodecs.MPEG4.ESDescriptor do
  @moduledoc """
  Module describing ES_Descriptor (defined in: ISO/IEC 14496-1)
  """

  import MediaCodecs.Helper

  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, SLConfigDescriptor}

  @type t :: %__MODULE__{
          es_id: integer(),
          stream_dependence_flag: boolean(),
          url_flag: boolean(),
          ocr_stream_flag: boolean(),
          stream_priority: integer(),
          depends_on_es_id: integer() | nil,
          url: String.t() | nil,
          ocr_es_id: integer() | nil,
          dec_config_descr: DecoderConfigDescriptor.t() | nil,
          sl_config_descr: SLConfigDescriptor | nil
        }

  defstruct [
    es_id: 0,
    stream_dependence_flag: false,
    url_flag: false,
    ocr_stream_flag: false,
    stream_priority: 4,
    depends_on_es_id: 0,
    url: nil,
    ocr_es_id: 0,
    dec_config_descr: nil,
    sl_config_descr: nil
  ]

  @doc """
  Parses the binary into an ESDescriptor struct.
  """
  @spec parse(binary()) :: t()
  def parse(
        <<es_id::16, stream_dependence_flag::1, url_flag::1, ocr_stream_flag::1,
          streamm_priority::5, rest::binary>>
      ) do
    {depends_on_es_id, rest} = dependant_es_id(stream_dependence_flag, rest)
    {url, rest} = url(url_flag, rest)
    {ocr_es_id, rest} = ocr_stream_id(ocr_stream_flag, rest)

    %__MODULE__{
      es_id: es_id,
      stream_dependence_flag: stream_dependence_flag == 1,
      url_flag: url_flag == 1,
      ocr_stream_flag: ocr_stream_flag == 1,
      stream_priority: streamm_priority,
      depends_on_es_id: depends_on_es_id,
      url: url,
      ocr_es_id: ocr_es_id
    }
    |> parse_descriptors(rest)
  end

  def serialize(%__MODULE__{} = descriptor) do
    decoder_config_descriptor = serialize_decoder_config_descriptor(descriptor.dec_config_descr)
    sl_config_descriptor = serialize_sl_config_descriptor(descriptor.sl_config_descr)

    depends_on_es_id =
      if descriptor.stream_dependence_flag == 1,
        do: <<descriptor.depends_on_es_id::16>>,
        else: <<>>

    url =
      if descriptor.url_flag == 1,
        do: <<byte_size(descriptor.url)::8, descriptor.url::binary>>,
        else: <<>>

    ocr_stream_id =
      if descriptor.ocr_stream_flag == 1, do: <<descriptor.ocr_es_id::16>>, else: <<>>

    es_descriptor =
      <<descriptor.es_id::16, bool_to_int(descriptor.stream_dependence_flag)::1,
        bool_to_int(descriptor.url_flag)::1, bool_to_int(descriptor.ocr_stream_flag)::1,
        descriptor.stream_priority::5, depends_on_es_id::binary, url::binary,
        ocr_stream_id::binary>>

    descriptor_size =
      byte_size(decoder_config_descriptor) + byte_size(es_descriptor) +
        byte_size(sl_config_descriptor)

    <<0x03>> <>
      base128_varint_encode(descriptor_size) <>
      es_descriptor <> decoder_config_descriptor <> sl_config_descriptor
  end

  defp dependant_es_id(1, <<es_id::16, rest::binary>>), do: {es_id, rest}
  defp dependant_es_id(0, data), do: {0, data}

  defp url(1, <<url_length::8, url::binary-size(url_length), rest::binary>>) do
    {url, rest}
  end

  defp url(0, data), do: {nil, data}

  defp ocr_stream_id(1, <<ocr_es_id::16, rest::binary>>), do: {ocr_es_id, rest}
  defp ocr_stream_id(0, data), do: {0, data}

  defp parse_descriptors(%__MODULE__{} = es_descriptor, <<>>), do: es_descriptor

  defp parse_descriptors(%__MODULE__{} = es_descriptor, data) do
    <<tag::8, rest::binary>> = data
    {size, rest} = base128_varint_decode(rest)
    <<descriptor_data::binary-size(size), rest::binary>> = rest

    es_descriptor =
      case tag do
        0x04 ->
          %{es_descriptor | dec_config_descr: DecoderConfigDescriptor.parse(descriptor_data)}

        0x06 ->
          %{es_descriptor | sl_config_descr: SLConfigDescriptor.parse(descriptor_data)}

        _tag ->
          es_descriptor
      end

    parse_descriptors(es_descriptor, rest)
  end

  defp serialize_decoder_config_descriptor(nil), do: <<>>

  defp serialize_decoder_config_descriptor(descriptor),
    do: DecoderConfigDescriptor.serialize(descriptor)

  defp serialize_sl_config_descriptor(nil), do: <<>>
  defp serialize_sl_config_descriptor(descriptor), do: SLConfigDescriptor.serialize(descriptor)
end
