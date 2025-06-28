defmodule MediaCodecs.H264.PPS do
  @moduledoc """
  Struct describing an H.264 Picture Parameter Set (PPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          pic_parameter_set_id: non_neg_integer(),
          seq_parameter_set_id: non_neg_integer(),
          entropy_coding_mode_flag: 0 | 1,
          bottom_field_pic_order_in_frame_present_flag: 0 | 1
        }

  defstruct [
    :pic_parameter_set_id,
    :seq_parameter_set_id,
    :entropy_coding_mode_flag,
    :bottom_field_pic_order_in_frame_present_flag
  ]

  @doc """
  Parses a PPS NALU from a binary string.
  """
  @spec parse(nal_body :: binary()) :: t()
  def parse(nalu_body) do
    nalu_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  defp do_parse(data) do
    {pic_parameter_set_id, data} = exp_golomb_uint(data)
    {seq_parameter_set_id, data} = exp_golomb_uint(data)

    <<entropy_coding_mode_flag::1, bottom_field_pic_order_in_frame_present_flag::1,
      _rest::bitstring>> = data

    %__MODULE__{
      pic_parameter_set_id: pic_parameter_set_id,
      seq_parameter_set_id: seq_parameter_set_id,
      entropy_coding_mode_flag: entropy_coding_mode_flag,
      bottom_field_pic_order_in_frame_present_flag: bottom_field_pic_order_in_frame_present_flag
    }
  end
end
