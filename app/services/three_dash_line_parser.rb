# frozen_string_literal: true

# app/services/three_dash_line_parser.rb
class ThreeDashLineParser < LineParser
  def parse(line)
    # We expect lines with at least two dashes and an extra note at the end.
    # This regex captures:
    #   - prod: the product name
    #   - meas: the first measurement (which may have no space between digits and unit)
    #   - vol: an optional parenthesized measurement (e.g., volume)
    #   - extra: an optional extra note starting with "np." at the end
    regex = /^-\s*(?<prod>.+?)\s*-\s*(?<meas>\d+(?:\/\d+)?(?:\s*\S+)+)(?:\s*\((?<vol>[^)]+)\))?(?:\s+(?<extra>np\..+))?$/
    if line.start_with?('-') && line.count('-') >= 2 && (match = regex.match(line))
      main_product = match[:prod].strip
      meas_str    = match[:meas].strip
      vol_str     = match[:vol]&.strip
      extra       = match[:extra]&.strip

      measurements = split_measurement(meas_str)
      if vol_str && include_number?(vol_str)
        measurements.concat(split_measurement(vol_str))
      end
      if extra && !extra.empty?
        main_product = "#{main_product} #{extra}".strip
      end

      return [main_product, measurements]
    end

    # Fallback: if our regex doesn't match, delegate to TwoDashLineParser.
    TwoDashLineParser.new.parse(line)
  end
end
