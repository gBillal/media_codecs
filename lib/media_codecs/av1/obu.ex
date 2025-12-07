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
  """
  @spec parse(binary()) :: {t(), binary()}
  def parse(data) do
    {header, rest} = Header.parse(data)
    {obu_paylaoad, rest} = obu_payload(header.has_size, rest)
    {%__MODULE__{header: header, payload: obu_paylaoad}, rest}
  end

  defp obu_payload(false, data), do: {data, <<>>}

  defp obu_payload(true, data) do
    {size, rest} = Helper.leb128_decode(data)

    case rest do
      <<payload::binary-size(size), rest::binary>> ->
        {payload, rest}

      _ ->
        raise ArgumentError, "Data too short to parse OBU payload of size #{size}"
    end
  end
end
