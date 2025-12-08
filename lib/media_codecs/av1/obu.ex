defmodule MediaCodecs.AV1.OBU do
  @moduledoc """
  Module describing an AV1 OBU (Open Bitstream Unit).
  """

  alias __MODULE__.Header
  alias MediaCodecs.Helper

  @type t :: %__MODULE__{
          header: Header.t(),
          payload: binary() | struct()
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

      iex> MediaCodecs.AV1.OBU.parse(<<10, 10, 0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>)
      {:ok,
       %MediaCodecs.AV1.OBU{
         header: %MediaCodecs.AV1.OBU.Header{
           type: :sequence_header,
           extension_flag: false,
           has_size: true,
           extension_header: nil
         },
         payload: <<0, 0, 0, 3, 54, 57, 231, 255, 204, 66>>
       }}
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, atom()}
  def parse(data) do
    with {:ok, header, rest} <- Header.parse(data),
         {:ok, obu_payload} <- obu_payload(header.has_size, rest) do
      {:ok, %__MODULE__{header: header, payload: obu_payload}}
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

  defp obu_payload(false, data), do: data

  defp obu_payload(true, data) do
    {size, payload} = Helper.leb128_decode(data)

    if byte_size(payload) == size,
      do: {:ok, payload},
      else: {:error, :invalid_payload}
  end
end
