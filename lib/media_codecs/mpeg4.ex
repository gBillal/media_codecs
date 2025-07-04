defmodule MediaCodecs.MPEG4 do
  @moduledoc """
  MPEG4 utilities.
  """

  import MediaCodecs.Helper, only: [base128_varint_decode: 1]

  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, ESDescriptor}

  @doc """
  Parses the binary into a list of descriptors.
  """
  @spec parse_descriptors(binary()) :: [struct()]
  def parse_descriptors(<<0x03, rest::binary>> = _data) do
    {descriptor_size, rest} = base128_varint_decode(rest)
    <<descriptor_data::binary-size(descriptor_size), rest::binary>> = rest
    [ESDescriptor.parse(descriptor_data) | parse_descriptors(rest)]
  end

  def parse_descriptors(<<0x04, rest::binary>> = _data) do
    {descriptor_size, rest} = base128_varint_decode(rest)
    <<descriptor_data::binary-size(descriptor_size), rest::binary>> = rest
    [DecoderConfigDescriptor.parse(descriptor_data) | parse_descriptors(rest)]
  end

  def parse_descriptors(<<>>), do: []
end
