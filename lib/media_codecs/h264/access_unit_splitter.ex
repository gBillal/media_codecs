defmodule MediaCodecs.H264.AccessUnitSplitter do
  @moduledoc """
  Module responsible for splitting a stream of H264 NAL units into access units.

  Most of the code copied from https://github.com/membraneframework/membrane_h26x_plugin/blob/v0.10.5/lib/membrane_h264_plugin/h264/au_splitter.ex
  """

  require Logger

  alias MediaCodecs.H264.NALU

  @type access_unit :: [binary()]

  @type t :: %__MODULE__{
          access_unit: access_unit(),
          stage: :first | :second,
          previous_nalu: NALU.t() | nil,
          parsed_sps: %{non_neg_integer() => NALU.t()},
          parsed_pps: %{non_neg_integer() => NALU.t()},
          sps: [binary()]
        }

  defstruct access_unit: [],
            stage: :first,
            previous_nalu: nil,
            parsed_sps: %{},
            parsed_pps: %{},
            sps: []

  @non_vcl_nalu_types_at_au_beginning [:sps, :pps, :aud, :sei]
  @non_vcl_nalu_types_at_au_end [:end_of_seq, :end_of_stream]

  @doc """
  Creates a new access unit splitter.
  """
  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @doc """
  Processes a NAL unit.
  """
  @spec process(nalu :: binary(), t()) :: {access_unit() | nil, t()}
  def process(nalu_data, splitter) do
    case parse_nalu(nalu_data, splitter) do
      {:ok, {nalu, splitter}} ->
        do_process(nalu_data, nalu, splitter)

      :error ->
        Logger.warning("[AccessUnitSplitter] Ignore invalid nal unit")
        {nil, splitter}
    end
  end

  @doc """
  Flushes the splitter and return the remaining nalus as an complete access unit
  """
  @spec flush(t()) :: access_unit()
  def flush(splitter), do: Enum.reverse(splitter.access_unit)

  defp do_process(nalu_data, nalu, %{stage: :first} = splitter) do
    cond do
      new_primary_coded_vcl_nalu?(nalu, splitter.previous_nalu) ->
        {nil,
         %{
           splitter
           | stage: :second,
             access_unit: [nalu_data | splitter.access_unit],
             previous_nalu: nalu
         }}

      nalu.type in @non_vcl_nalu_types_at_au_beginning ->
        {nil, %{splitter | access_unit: [nalu_data | splitter.access_unit]}}

      true ->
        Logger.warning("[AccessUnitSplitter]: Invalid transition, ignore nal unit")
        {nil, splitter}
    end
  end

  defp do_process(nalu_data, nalu, %{stage: :second} = splitter) do
    cond do
      nalu.type in @non_vcl_nalu_types_at_au_end ->
        {nil, %{splitter | access_unit: [nalu_data | splitter.access_unit]}}

      nalu.type in @non_vcl_nalu_types_at_au_beginning ->
        access_unit = Enum.reverse(splitter.access_unit)
        {access_unit, %{splitter | stage: :first, access_unit: [nalu_data]}}

      new_primary_coded_vcl_nalu?(nalu, splitter.previous_nalu) ->
        access_unit = Enum.reverse(splitter.access_unit)
        {access_unit, %{splitter | previous_nalu: nalu, access_unit: [nalu_data]}}

      NALU.vcl?(nalu) or nalu.type == :filler_data ->
        {nil, %{splitter | access_unit: [nalu | splitter.access_unit]}}

      true ->
        Logger.warning("[AccessUnitSplitter]: Invalid transition, ignore nal unit")
        {nil, splitter}
    end
  end

  defp parse_nalu(nalu, splitter) do
    case NALU.type(nalu) do
      :pps ->
        pps = NALU.parse(nalu)

        splitter = %{
          splitter
          | parsed_pps: Map.put(splitter.parsed_pps, pps.content.pic_parameter_set_id, pps)
        }

        {:ok, {pps, splitter}}

      :sps ->
        if nalu not in splitter.sps do
          sps = NALU.parse(nalu)

          splitter = %{
            splitter
            | sps: [nalu | splitter.sps],
              parsed_sps: Map.put(splitter.parsed_sps, sps.content.seq_parameter_set_id, sps)
          }

          {:ok, {sps, splitter}}
        else
          {:ok, {splitter.parsed_sps[NALU.SPS.id(nalu)], splitter}}
        end

      _other ->
        pps = fn pps_id ->
          pps = splitter.parsed_pps[pps_id]
          pps && pps.content
        end

        sps = fn pps_id ->
          pps = splitter.parsed_pps[pps_id]
          sps = pps && splitter.parsed_sps[pps.content.seq_parameter_set_id]
          sps && sps.content
        end

        nalu = NALU.parse(nalu, sps: sps, pps: pps)

        if NALU.vcl?(nalu) and is_nil(nalu.content.frame_num),
          do: :error,
          else: {:ok, {nalu, splitter}}
    end
  end

  defguardp first_mb_in_slice_zero(a)
            when a.content.first_mb_in_slice == 0 and
                   a.type in [:non_idr, :part_a, :idr]

  defguardp frame_num_differs(a, b) when a.frame_num != b.frame_num

  defguardp pic_parameter_set_id_differs(a, b)
            when a.pic_parameter_set_id != b.pic_parameter_set_id

  defguardp field_pic_flag_differs(a, b) when a.field_pic_flag != b.field_pic_flag

  defguardp bottom_field_flag_differs(a, b) when a.bottom_field_flag != b.bottom_field_flag

  defguardp nal_ref_idc_differs_one_zero(a, b)
            when (a.nal_ref_idc == 0 or b.nal_ref_idc == 0) and
                   a.nal_ref_idc != b.nal_ref_idc

  defguardp pic_order_cnt_zero_check(a, b)
            when a.pic_order_cnt_lsb != b.pic_order_cnt_lsb or
                   a.delta_pic_order_cnt_bottom != b.delta_pic_order_cnt_bottom

  defguardp idr_and_non_idr(a, b) when (a.type == :idr or b.type == :idr) and a.type != b.type

  defguardp idrs_with_idr_pic_id_differ(a, b)
            when a.type == :idr and b.type == :idr and
                   a.content.idr_pic_id != b.content.idr_pic_id

  defp new_primary_coded_vcl_nalu?(nalu, previous_nalu) do
    cond do
      not NALU.vcl?(nalu) -> false
      is_nil(previous_nalu) -> true
      true -> primary_coded_vcl_nalu?(nalu, previous_nalu)
    end
  end

  # Conditions based on 7.4.1.2.4 "Detection of the first VCL NAL unit of a primary coded picture"
  # of the "ITU-T Rec. H.264 (01/2012)"
  defp primary_coded_vcl_nalu?(
         %{content: nalu_content} = nalu,
         %{content: last_nalu_content} = last_nalu
       )
       when first_mb_in_slice_zero(nalu)
       when frame_num_differs(nalu_content, last_nalu_content)
       when pic_parameter_set_id_differs(nalu_content, last_nalu_content)
       when field_pic_flag_differs(nalu_content, last_nalu_content)
       when bottom_field_flag_differs(nalu_content, last_nalu_content)
       when nal_ref_idc_differs_one_zero(nalu, last_nalu)
       when pic_order_cnt_zero_check(nalu_content, last_nalu_content)
       when idr_and_non_idr(nalu, last_nalu)
       when idrs_with_idr_pic_id_differ(nalu, last_nalu) do
    true
  end

  defp primary_coded_vcl_nalu?(_nalu, _last_nalu) do
    false
  end
end
