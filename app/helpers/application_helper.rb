# frozen_string_literal: true

module ApplicationHelper
  # Splits instructions into parts when numbering restarts (e.g. 1,2,3 then 1 again for salad).
  # Returns array of { title:, steps: } where steps are plain strings (no "1. " prefix).
  def instruction_parts(instructions)
    return [] if instructions.blank?

    # Split by newline before "N. " OR by ". 1. " (restart numbering on same line)
    raw_steps = instructions.split(/\n(?=\d+\.\s)|(?<=[.!?])\s+(?=\d+\.\s)/)
    raw_steps = raw_steps.map(&:strip).reject(&:blank?)
    return [] if raw_steps.empty? || !raw_steps.first.match?(/^\d+\.\s/)

    parts = []
    current = []

    raw_steps.each do |raw|
      step_num = raw.match(/\A(\d+)\.\s/)
      text = raw.gsub(/\A\d+\.\s*/, '').strip
      next if text.blank?

      # New part when numbering restarts (e.g. "1." after "2." or "3.")
      if step_num && step_num[1] == '1' && current.any?
        parts << { title: part_title(current.first, parts.size), steps: current }
        current = []
      end
      current << text
    end
    parts << { title: part_title(current.first, parts.size), steps: current } if current.any?
    parts
  end

  def part_title(first_step_text, part_index)
    t = first_step_text.to_s.downcase
    return 'Surówka' if t.match?(/kapust|surówk|cebul|marchew|burak/)
    # "Sos" only when step is clearly a sauce recipe (e.g. "Sos: wymieszać..."), not when sauce is just mentioned
    return 'Sos' if t.match?(/^(sos\b|sos:\s|przygotować sos|zrobić sos)/)
    return part_index.zero? ? 'Danie główne' : 'Dodatki'
  end

  def format_instruction_steps(steps)
    return '' if steps.blank?

    list_items = steps.map do |step|
      content_tag(:li, step, class: 'ml-2 mt-2 first:mt-0')
    end
    content_tag(:ol, safe_join(list_items), class: 'list-decimal list-inside space-y-2')
  end

  # Renders meal preparation instructions. If the text contains numbered steps (one per line),
  # splits by restarted numbering, adds per-part headings, and renders ordered lists.
  def format_meal_instructions(instructions)
    return '' if instructions.blank?

    parts = instruction_parts(instructions)
    if parts.any?
      parts.map do |part|
        tag.div(class: 'mb-4 last:mb-0') do
          tag.h4(part[:title], class: 'mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500') +
            tag.div(format_instruction_steps(part[:steps]), class: 'p-2 text-sm prose bg-gray-100 rounded')
        end
      end.reduce(&:+)
    else
      # Fallback: single block, no numbered sublists
      tag.div(class: 'mb-4') do
        tag.h4('Sposób przygotowania', class: 'mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500') +
          tag.div(simple_format(instructions), class: 'p-2 text-sm prose bg-gray-100 rounded')
      end
    end
  end
end
