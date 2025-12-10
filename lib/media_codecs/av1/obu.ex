defmodule MediaCodecs.AV1.OBU do
  @moduledoc """
  Module describing an AV1 OBU (Open Bitstream Unit).
  """

  alias __MODULE__.{Header, SequenceHeader}
  alias MediaCodecs.Helper

  @type t :: %__MODULE__{
          header: Header.t(),
          payload: binary() | SequenceHeader.t()
        }

  defstruct [:header, :payload]

  @doc """
  Returns the OBU type from a binary OBU.

      iex> MediaCodecs.AV1.OBU.type(<<10, 10, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>)
      :sequence_header
  """
  @spec type(binary()) :: Header.obu_type()
  def type(obu), do: Header.type(obu)

  @doc """
  Parses a binary into an OBU struct.

      iex> MediaCodecs.AV1.OBU.parse(<<18, 0>>)
      {:ok,
       %MediaCodecs.AV1.OBU{
         header: %MediaCodecs.AV1.OBU.Header{
           type: :temporal_delimiter,
           extension_flag: false,
           has_size: true,
           extension_header: nil
         },
         payload: <<>>
       }}
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, atom()}
  def parse(data) do
    with {:ok, header, rest} <- Header.parse(data),
         {:ok, obu_payload} <- obu_payload(header.has_size, rest) do
      {:ok, %__MODULE__{header: header, payload: parse_payload(header.type, obu_payload)}}
    end
  end

  @doc """
  Same as `parse/1`, but raises an error if parsing fails.
  """
  @spec parse!(binary()) :: t()
  def parse!(data) do
    case parse(data) do
      {:ok, obu} -> obu
      {:error, reason} -> raise "Failed to parse OBU: #{reason}"
    end
  end

  @doc """
  Clears the `obu_has_size` flag.

      iex> MediaCodecs.AV1.OBU.clear_size_flag(<<10, 10, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>)
      <<8, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>
  """
  @spec clear_size_flag(binary()) :: binary()
  def clear_size_flag(<<_::6, 0::1, _::bitstring>> = obu), do: obu

  def clear_size_flag(
        <<header_start::5, ext_flag::1, _::1, header_end::size(ext_flag * 8 + 1), rest::binary>>
      ) do
    {_size, payload} = Helper.leb128_decode(rest)
    <<header_start::5, ext_flag::1, 0::1, header_end::size(ext_flag * 8 + 1), payload::binary>>
  end

  @doc """
  Sets the `obu_has_size` flag.

      iex> MediaCodecs.AV1.OBU.set_size_flag(<<8, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>)
      <<10, 10, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>
  """
  @spec set_size_flag(binary()) :: binary()
  def set_size_flag(<<_::6, 1::1, _::bitstring>> = obu), do: obu

  def set_size_flag(
        <<header_start::5, ext_flag::1, _::1, header_end::size(ext_flag * 8 + 1), rest::binary>>
      ) do
    leb128_size = Helper.leb128_encode(byte_size(rest))

    <<header_start::5, 0::1, 1::1, header_end::size(ext_flag * 8 + 1), leb128_size::binary,
      rest::binary>>
  end

  @doc """
  Checks if an OBU is a keyframe.

      iex> MediaCodecs.AV1.OBU.keyframe?(<<18, 0>>)
      false

      iex> MediaCodecs.AV1.OBU.keyframe?(<<10, 11, 0, 0, 0, 66, 167, 191, 230, 46, 223, 200, 66>>)
      false

      iex> MediaCodecs.AV1.OBU.keyframe?(<<50, 218, 169, 3, 20, 0, 52, 162, 224, 0, 0, 136, 0>>)
      true
  """
  @spec keyframe?(binary()) :: boolean()
  def keyframe?(<<0::1, type::4, _::bitstring>>) when type != 3 and type != 6, do: false
  def keyframe?(<<0::1, _::4, 0::1, 0::2, 0::3, 1::1, _::bitstring>>), do: true
  def keyframe?(<<0::1, _::4, 1::1, 0::10, 0::3, 1::1, _::bitstring>>), do: true

  def keyframe?(<<0::1, _::4, extension::1, _::size(extension * 8 + 2), rest::binary>>) do
    {_size, rest} = Helper.leb128_decode(rest)
    match?(<<0::3, 1::1, _::bitstring>>, rest)
  end

  def keyframe?(_other), do: false

  defp obu_payload(false, data), do: {:ok, data}

  defp obu_payload(true, data) do
    {size, payload} = Helper.leb128_decode(data)

    if byte_size(payload) == size,
      do: {:ok, payload},
      else: {:error, :invalid_payload}
  end

  defp parse_payload(:sequence_header, payload), do: SequenceHeader.parse(payload)
  defp parse_payload(_other, payload), do: payload
end
