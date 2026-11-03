module InitiativesHelper
  # Packs initiatives into the minimum number of non-overlapping rows (lanes)
  # to maximize vertical information density.
  #
  # Two initiatives are placed on the same line if there is no overlap
  # (i.e. if the start date of the second initiative is after the end date of the first,
  # even with just one day difference).
  def pack_initiatives_into_lanes(initiatives, start_window = Date.current)
    with_ranges = initiatives.map do |initiative|
      s_date = initiative.start_date || (initiative.end_date ? initiative.end_date - 2.weeks : start_window)
      e_date = [ initiative.end_date || (s_date + 2.weeks), s_date ].max
      { initiative: initiative, start_date: s_date, end_date: e_date }
    end

    sorted = with_ranges.sort_by { |item| [ item[:start_date], item[:end_date], item[:initiative].title.to_s ] }

    lanes = []
    sorted.each do |item|
      lane = lanes.find { |l| item[:start_date] > l[:last_end_date] }
      if lane
        lane[:items] << item
        lane[:last_end_date] = item[:end_date]
      else
        lanes << { last_end_date: item[:end_date], items: [ item ] }
      end
    end

    lanes
  end
end
