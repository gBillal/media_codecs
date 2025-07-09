defmodule MediaCodecs.MPEG4 do
  @moduledoc """
  MPEG4 utilities.
  """

  import MediaCodecs.Helper, only: [base128_varint_decode: 1]

  alias MediaCodecs.MPEG4.ADTS
  alias MediaCodecs.MPEG4.{DecoderConfigDescriptor, ESDescriptor, SLConfigDescriptor}

  @doc """
  Parses the binary into a list of descriptors.

  Unknown descritpors are ignored.
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

  @doc """
  Parses an ADTS stream into a list of ADTS packets.

  This function returns:
    * `{:ok, packets, unprocessed}` where `packets` is a list of parsed ADTS packets and `unprocessed` is the remaining unprocessed binary.
    * `{:error, :invalid_packet}` if an invalid packet is encountered.
  """
  @spec parse_adts_stream(binary()) :: {:ok, [ADTS.t()], binary()} | {:error, :invalid_packet}
  def parse_adts_stream(stream), do: do_parse_adts_stream(stream, [])

  @doc """
  Same as `parse_adts_stream/1`, but raises an error if an invalid packet is encountered.
  """
  @spec parse_adts_stream!(binary()) :: {[ADTS.t()], binary()}
  def parse_adts_stream!(stream) do
    case do_parse_adts_stream(stream, []) do
      {:ok, packets, unprocessed} -> {packets, unprocessed}
      {:error, :invalid_packet} -> raise "Invalid ADTS packet encountered"
    end
  end

  defp do_parse_adts_stream(stream, acc) do
    case ADTS.parse(stream) do
      {:ok, packet, rest} ->
        do_parse_adts_stream(rest, [packet | acc])

      :more ->
        {:ok, Enum.reverse(acc), stream}

      {:error, :invalid_packet} ->
        {:error, :invalid_packet}
    end
  end
end
