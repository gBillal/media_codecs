defmodule MediaCodecs.H265.NALU.PPS do
  @moduledoc """
  Struct describing an H.265 Picture Parameter Set (PPS).
  """

  import MediaCodecs.Helper

  @type t :: %__MODULE__{
          pic_parameter_set_id: non_neg_integer(),
          seq_parameter_set_id: non_neg_integer(),
          dependent_slice_segments_enabled_flag: 0 | 1,
          output_flag_present_flag: 0 | 1,
          num_extra_slice_header_bits: non_neg_integer()
        }

  defstruct [
    :pic_parameter_set_id,
    :seq_parameter_set_id,
    :dependent_slice_segments_enabled_flag,
    :output_flag_present_flag,
    :num_extra_slice_header_bits
  ]

  @doc """
  Parses a PPS NALU from a binary string.
  """
  @spec parse(nalu :: binary()) :: t()
  def parse(<<_heaader::16, nal_body::binary>> = _nalu) do
    nal_body
    |> emulation_prevention_remove()
    |> do_parse()
  end

  defp do_parse(data) do
    {pic_parameter_set_id, data} = exp_golomb_uint(data)
    {seq_parameter_set_id, data} = exp_golomb_uint(data)

    <<dependent_slice_segments_enabled_flag::1, output_flag_present_flag::1,
      num_extra_slice_header_bits::3, _rest::bitstring>> = data

    %__MODULE__{
      pic_parameter_set_id: pic_parameter_set_id,
      seq_parameter_set_id: seq_parameter_set_id,
      dependent_slice_segments_enabled_flag: dependent_slice_segments_enabled_flag,
      output_flag_present_flag: output_flag_present_flag,
      num_extra_slice_header_bits: num_extra_slice_header_bits
    }
  end
end
