# frozen_string_literal: true

module InitiativesHelper
  # Packs initiatives into the minimum number of non-overlapping rows (lanes)
  # to maximize vertical information density.
  #
  # Two initiatives are placed on the same line if there is no overlap
  # (i.e. if the start date of the second initiative is after the end date of the first,
  # even with just one day difference).
  def pack_initiatives_into_lanes(initiatives, start_window = Date.current)
    sorted = initiatives.sort_by do |i|
      s = i.start_date || start_window
      e = [ i.end_date || (s + 2.weeks), s ].max
      [ s, e, i.title.to_s ]
    end

    lanes = []
    sorted.each do |initiative|
      s_date = initiative.start_date || start_window
      e_date = [ initiative.end_date || (s_date + 2.weeks), s_date ].max

      placed = false
      lanes.each do |lane|
        if s_date > lane[:last_end_date]
          lane[:items] << { initiative: initiative, start_date: s_date, end_date: e_date }
          lane[:last_end_date] = e_date
          placed = true
          break
        end
      end

      unless placed
        lanes << {
          last_end_date: e_date,
          items: [ { initiative: initiative, start_date: s_date, end_date: e_date } ]
        }
      end
    end

    lanes
  end
end
