defmodule MediaCodecs.H265.NALU.VPS do
  @moduledoc """
  Struct describing an H.265 Video Parameter Set (VPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          video_parameter_set_id: non_neg_integer()
        }

  defstruct [:video_parameter_set_id]

  @doc """
  Parses a VPS NALU from a binary string.
  """
  @spec parse(nalu :: binary()) :: t()
  def parse(<<_header::16, nal_body::binary>> = _nalu) do
    nal_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  @doc """
  Gets the VPS ID.
  """
  @spec id(nalu :: binary()) :: non_neg_integer()
  def id(<<_header::16, id::4, _rest::bitstring>>), do: id

  defp do_parse(<<video_parameter_set_id::4, _rest::bitstring>>) do
    %__MODULE__{video_parameter_set_id: video_parameter_set_id}
  end
end
