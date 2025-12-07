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

  defp obu_payload(false, data), do: data

  defp obu_payload(true, data) do
    {size, payload} = Helper.leb128_decode(data)

    if byte_size(payload) == size,
      do: {:ok, payload},
      else: {:error, :invalid_payload}
  end
end
