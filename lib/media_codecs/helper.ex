defmodule MediaCodecs.Helper do
  @moduledoc false

  import Bitwise

  @spec exp_golomb_uint(bitstring(), non_neg_integer()) ::
          {non_neg_integer(), bitstring()}
  @spec exp_golomb_uint(bitstring()) :: {non_neg_integer(), bitstring()}
  def exp_golomb_uint(binary, zeros_count \\ 0)

  def exp_golomb_uint(<<0::1, data::bitstring>>, zeros_count) do
    exp_golomb_uint(data, zeros_count + 1)
  end

  def exp_golomb_uint(data, zeros_count) do
    <<number::size(zeros_count + 1), data::bitstring>> = data
    {number - 1, data}
  end

  @spec exp_golomb_int(bitstring(), non_neg_integer()) :: {integer(), bitstring()}
  @spec exp_golomb_int(bitstring()) :: {integer(), bitstring()}
  def exp_golomb_int(binary, zeros_count \\ 0)

  def exp_golomb_int(<<0::1, data::bitstring>>, zeros_count) do
    exp_golomb_int(data, zeros_count + 1)
  end

  def exp_golomb_int(data, zeros_count) do
    <<number::size(zeros_count + 1), data::bitstring>> = data
    number = number - 1

    if rem(number, 2) == 0 do
      {-div(number, 2), data}
    else
      {div(number + 1, 2), data}
    end
  end

  @spec emulation_prevention_remove(bitstring()) :: bitstring()
  def emulation_prevention_remove(data) do
    :binary.split(data, <<0, 0, 3>>, [:global]) |> Enum.join(<<0, 0>>)
  end

  @doc """
  Decodes a Base128 variable-length integer from the given binary data.
  """
  def base128_varint_decode(data) do
    do_base128_varint_decode(data, 0)
  end

  defp do_base128_varint_decode(<<stop_bit::1, length::7, rest::binary>>, acc) do
    acc = acc <<< 7 ||| length

    case stop_bit do
      1 -> do_base128_varint_decode(rest, acc)
      0 -> {acc, rest}
    end
  end
end
