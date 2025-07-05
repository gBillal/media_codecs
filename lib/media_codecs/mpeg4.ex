defmodule MediaCodecs.MPEG4 do
  @moduledoc """
  MPEG4 utilities.
  """

  import MediaCodecs.Helper, only: [base128_varint_decode: 1]

  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, ESDescriptor, SLConfigDescriptor}

  @doc """
  Parses the binary into a list of descriptors.
  """
  @spec parse_descriptors(binary()) :: [struct()]
  def parse_descriptors(<<tag, rest::binary>> = _data) do
    {descriptor_size, rest} = base128_varint_decode(rest)
    <<descriptor_data::binary-size(descriptor_size), rest::binary>> = rest

    case tag do
      0x03 -> [ESDescriptor.parse(descriptor_data) | parse_descriptors(rest)]
      0x04 -> [DecoderConfigDescriptor.parse(descriptor_data) | parse_descriptors(rest)]
      0x06 -> [SLConfigDescriptor.parse(descriptor_data) | parse_descriptors(rest)]
      _other -> parse_descriptors(rest)
    end
  end

  def parse_descriptors(<<>>), do: []
end
