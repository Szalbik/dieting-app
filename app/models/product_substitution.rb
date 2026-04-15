# frozen_string_literal: true

class ProductSubstitution < ApplicationRecord
  belongs_to :user
  belongs_to :source_canonical_product, class_name: 'CanonicalProduct', optional: true
  belongs_to :replacement_canonical_product, class_name: 'CanonicalProduct', optional: true

  validates :source_product, :replacement_product, presence: true
  validates :replacement_product, uniqueness: { scope: [:user_id, :source_product] }

  before_validation :normalize_products_and_quantities
  before_validation :sync_canonical_products!

  normalizes :source_product, with: ->(value) { value.to_s.strip.presence }
  normalizes :replacement_product, with: ->(value) { value.to_s.strip.presence }

  def self.suggestions_for_names(user:, product_names:)
    substitutions = user.product_substitutions.to_a
    prepared = substitutions.map do |sub|
      [normalize_name(sub.source_product), sub.replacement_product]
    end

    product_names.index_with do |name|
      normalized_name = normalize_name(name)
      prepared
        .select { |source, _replacement| normalized_name.include?(source) || source.include?(normalized_name) }
        .map(&:last)
        .uniq
    end
  end

  def self.connected_names_for(user:, product_name:)
    rows = user.product_substitutions.pluck(:source_product, :replacement_product)
    return [] if rows.empty? || product_name.blank?

    normalized_current = normalize_name(product_name)
    adjacency = Hash.new { |h, k| h[k] = [] }
    canonical = {}
    seed_nodes = []

    rows.each do |source, replacement|
      source_norm = normalize_name(source)
      replacement_norm = normalize_name(replacement)
      next if source_norm.blank? || replacement_norm.blank?

      canonical[source_norm] ||= source
      canonical[replacement_norm] ||= replacement

      adjacency[source_norm] << replacement_norm
      adjacency[replacement_norm] << source_norm

      if source_norm.include?(normalized_current) || normalized_current.include?(source_norm) ||
          replacement_norm.include?(normalized_current) || normalized_current.include?(replacement_norm)
        seed_nodes << source_norm
        seed_nodes << replacement_norm
      end
    end

    return [] if seed_nodes.empty?

    visited = {}
    queue = seed_nodes.uniq
    ordered_nodes = []

    until queue.empty?
      node = queue.shift
      next if visited[node]

      visited[node] = true
      ordered_nodes << node
      adjacency[node].each { |neighbor| queue << neighbor unless visited[neighbor] }
    end

    names = ordered_nodes.map { |node| canonical[node] }.compact.uniq
    current_present = names.any? { |name| normalize_name(name) == normalized_current }
    current_present ? names : [product_name, *names].uniq
  end

  def self.conversion_factor_between(user:, from_name:, to_name:)
    graph, canon = substitution_graph(user)
    from = match_node(canon, from_name)
    to = match_node(canon, to_name)
    return 1.0 if from.blank? || to.blank? || from == to

    factor_between(graph, from, to) || 1.0
  end

  def self.next_replacement_for(user:, current_name:)
    options = connected_names_for(user: user, product_name: current_name)
    return nil if options.size < 2

    current_norm = normalize_name(current_name)
    current_idx = options.index { |name| normalize_name(name) == current_norm } || 0
    next_name = options[(current_idx + 1) % options.size]
    factor = conversion_factor_between(user: user, from_name: current_name, to_name: next_name)
    { name: strip_quantity_from_name(next_name), factor: factor }
  end

  def self.local_replacements_for_base(user:, base_name:)
    canonical_base = Local::CanonicalProductResolver.new(user: user).resolve_existing(raw_name: base_name)
    if canonical_base.present?
      names = user.product_substitutions
        .where(source_canonical_product_id: canonical_base.id)
        .includes(:replacement_canonical_product)
        .order(:id)
        .map { |sub| sub.replacement_canonical_product&.name || strip_quantity_from_name(sub.replacement_product) }
      return canonical_dedup(names)
    end

    base_norm = normalize_name(base_name)
    return [] if base_norm.blank?

    user.product_substitutions
      .select { |sub| source_matches_base?(sub.source_product, base_norm) }
      .sort_by(&:id)
      .map { |sub| strip_quantity_from_name(sub.replacement_product) }
      .uniq
  end

  def self.local_cycle_for(user:, base_name:)
    base_clean = canonical_name_for_user(user: user, raw_name: base_name)
    replacements = local_replacements_for_base(user: user, base_name: base_clean)
      .map { |name| canonical_name_for_user(user: user, raw_name: name) }
    canonical_dedup([base_clean, *replacements])
  end

  def self.local_factor_for(user:, base_name:, from_name:, to_name:)
    resolver = Local::CanonicalProductResolver.new(user: user)
    base_canonical = resolver.resolve_existing(raw_name: base_name)
    from_canonical = resolver.resolve_existing(raw_name: from_name)
    to_canonical = resolver.resolve_existing(raw_name: to_name)

    if base_canonical.present?
      pairs = user.product_substitutions
        .where(source_canonical_product_id: base_canonical.id)
        .each_with_object({}) do |sub, output|
          replacement_id = sub.replacement_canonical_product_id
          next if replacement_id.blank?

          output[replacement_id] = multiplier_for(sub)
        end

      from_id = from_canonical&.id || base_canonical.id
      to_id = to_canonical&.id || base_canonical.id

      return 1.0 if from_id == to_id

      if from_id == base_canonical.id
        ratio = pairs[to_id]
        return ratio if ratio.present? && ratio.positive?
      elsif to_id == base_canonical.id
        ratio = pairs[from_id]
        return 1.0 / ratio if ratio.present? && ratio.positive?
      else
        from_ratio = pairs[from_id]
        to_ratio = pairs[to_id]
        if from_ratio.present? && to_ratio.present? && from_ratio.positive?
          return to_ratio / from_ratio
        end
      end
    end

    base_norm = normalize_name(base_name)
    from_norm = normalize_name(from_name)
    to_norm = normalize_name(to_name)
    return 1.0 if from_norm.blank? || to_norm.blank? || from_norm == to_norm

    pairs = user.product_substitutions
      .select { |sub| source_matches_base?(sub.source_product, base_norm) }
      .map { |sub| [normalize_name(sub.replacement_product), multiplier_for(sub)] }
      .to_h

    if from_norm == base_norm
      ratio = pairs[to_norm]
      return ratio if ratio.present? && ratio.positive?

      return 1.0
    end

    if to_norm == base_norm
      ratio = pairs[from_norm]
      return 1.0 if ratio.blank? || ratio <= 0

      return 1.0 / ratio
    end

    from_ratio = pairs[from_norm]
    to_ratio = pairs[to_norm]
    return 1.0 if from_ratio.blank? || to_ratio.blank? || from_ratio <= 0

    to_ratio / from_ratio
  end

  def self.multiplier_for(substitution)
    explicit = substitution.amount_multiplier.to_f
    return explicit if explicit.positive?

    src_scale = unit_scale(substitution.source_unit)
    rep_scale = unit_scale(substitution.replacement_unit)
    return nil if src_scale.blank? || rep_scale.blank?
    return nil unless src_scale.first == rep_scale.first
    return nil if substitution.source_amount.to_f <= 0 || substitution.replacement_amount.to_f <= 0

    source_base = substitution.source_amount.to_f * src_scale.last
    replacement_base = substitution.replacement_amount.to_f * rep_scale.last
    return nil if source_base <= 0

    replacement_base / source_base
  end

  def self.source_matches_base?(source_product, base_norm)
    source_norm = normalize_name(source_product)
    return true if source_norm == base_norm

    source_stem = normalize_polish_stem(source_norm)
    base_stem = normalize_polish_stem(base_norm)
    return false if source_stem.blank? || base_stem.blank?

    source_stem == base_stem
  end

  def self.normalize_polish_stem(normalized_value)
    token = normalized_value.to_s.strip
    return token if token.length < 4

    # Basic Polish inflection fallback for food names:
    # banan <-> banana, brokul <-> brokulu, jogurt <-> jogurtu, etc.
    token = token.delete_suffix('u') if token.end_with?('u') && token.length > 4
    token = token.delete_suffix('a') if token.end_with?('a') && token.length > 4
    token = token.delete_suffix('y') if token.end_with?('y') && token.length > 4
    token = token.delete_suffix('i') if token.end_with?('i') && token.length > 4
    token
  end

  def self.strip_quantity_from_name(value)
    _, _, _, stripped = parse_quantity_from_text(value)
    stripped
  end

  def self.canonical_name_for_user(user:, raw_name:)
    cleaned = strip_quantity_from_name(raw_name).to_s.strip
    return cleaned if cleaned.blank? || user.blank?

    Local::CanonicalProductResolver.new(user: user).call(raw_name: cleaned)&.name || cleaned
  end

  def self.normalize_name(value)
    I18n.transliterate(value.to_s)
      .downcase
      .gsub(/[^a-z0-9\s]/, ' ')
      .squeeze(' ')
      .strip
  end

  def self.substitution_graph(user)
    rows = user.product_substitutions.select(
      :source_product, :replacement_product, :amount_multiplier
    )
    graph = Hash.new { |h, k| h[k] = [] }
    canon = {}

    rows.each do |row|
      source = normalize_name(row.source_product)
      replacement = normalize_name(row.replacement_product)
      next if source.blank? || replacement.blank?

      canon[source] ||= row.source_product
      canon[replacement] ||= row.replacement_product

      multiplier = row.amount_multiplier.to_f
      multiplier = nil if multiplier <= 0

      graph[source] << [replacement, multiplier]
      reverse = multiplier.present? ? (1.0 / multiplier) : nil
      graph[replacement] << [source, reverse]
    end

    [graph, canon]
  end

  def self.match_node(canon, name)
    normalized = normalize_name(name)
    return normalized if canon.key?(normalized)

    canon.keys.find { |key| normalized.include?(key) || key.include?(normalized) }
  end

  def self.factor_between(graph, from, to)
    queue = [[from, 1.0]]
    visited = {}

    until queue.empty?
      node, factor = queue.shift
      next if visited[node]

      visited[node] = true
      return factor if node == to

      graph[node].each do |neighbor, edge_factor|
        next if visited[neighbor]

        queue << [neighbor, factor * (edge_factor || 1.0)]
      end
    end

    nil
  end

  def self.parse_quantity_from_text(value)
    text = value.to_s.strip.gsub(/\s+/, ' ')
    return [nil, nil, nil, text] if text.blank?

    bracket_match = text.match(/\A(?<name>.+?)\s*\((?<amount>\d+(?:[.,]\d+)?(?:\/\d+(?:[.,]\d+)?)?)\s*(?<unit>[[:alpha:]\p{L}%\.]+)\)\s*\z/u)
    return parsed_match(bracket_match) if bracket_match

    trailing_match = text.match(/\A(?<name>.+?)\s+(?<amount>\d+(?:[.,]\d+)?(?:\/\d+(?:[.,]\d+)?)?)\s*(?<unit>[[:alpha:]\p{L}%\.]+)\s*\z/u)
    return parsed_match(trailing_match) if trailing_match

    leading_match = text.match(/\A(?<amount>\d+(?:[.,]\d+)?(?:\/\d+(?:[.,]\d+)?)?)\s*(?<unit>[[:alpha:]\p{L}%\.]+)\s+(?<name>.+?)\s*\z/u)
    return parsed_match(leading_match) if leading_match

    [nil, nil, nil, text]
  end

  def self.parsed_match(match)
    amount_raw = match[:amount].to_s
    unit_raw = match[:unit].to_s
    name_raw = match[:name].to_s

    amount = if amount_raw.include?('/')
      num, den = amount_raw.split('/', 2)
      den_value = den.to_s.tr(',', '.').to_f
      den_value.zero? ? nil : num.to_s.tr(',', '.').to_f / den_value
    else
      amount_raw.tr(',', '.').to_f
    end

    unit = normalize_unit(unit_raw)
    name = name_raw.gsub(/\s+/, ' ').strip
    [amount, unit, unit_scale(unit), name]
  end

  def self.normalize_unit(unit)
    normalized = I18n.transliterate(unit.to_s).downcase.gsub('.', '').strip
    return 'g' if %w[g gram gr].include?(normalized)
    return 'kg' if normalized == 'kg'
    return 'ml' if normalized == 'ml'
    return 'l' if normalized == 'l'
    return 'szt' if %w[szt sztuka sztuki].include?(normalized)

    normalized
  end

  def self.unit_scale(unit)
    case unit
    when 'g' then [:mass, 1.0]
    when 'kg' then [:mass, 1000.0]
    when 'ml' then [:volume, 1.0]
    when 'l' then [:volume, 1000.0]
    when 'szt' then [:count, 1.0]
    else
      nil
    end
  end

  def self.best_catalog_match(user:, raw_name:, min_score: 0.72)
    return nil if user.blank? || raw_name.blank?

    source_norm = normalize_name(raw_name)
    source_tokens = source_norm.split.map { |token| normalize_polish_stem(token) }.reject(&:blank?)
    return nil if source_tokens.empty?

    best_name = nil
    best_score = 0.0

    user.products.pluck(:name).uniq.each do |candidate|
      candidate_norm = normalize_name(candidate)
      candidate_tokens = candidate_norm.split.map { |token| normalize_polish_stem(token) }.reject(&:blank?)
      next if candidate_tokens.empty?

      token_score = token_similarity(source_tokens, candidate_tokens)
      char_score = char_similarity(source_norm, candidate_norm)
      score = (0.72 * token_score) + (0.28 * char_score)
      next if score < min_score || score <= best_score

      best_score = score
      best_name = candidate
    end

    best_name
  end

  def self.canonical_dedup(names)
    seen = {}
    names.each_with_object([]) do |name, output|
      normalized = normalize_name(name)
      stem = normalized.split.map { |token| normalize_polish_stem(token) }.join(' ')
      key = stem.presence || normalized
      next if key.blank? || seen[key]

      seen[key] = true
      output << name
    end
  end

  def self.token_similarity(a_tokens, b_tokens)
    a = a_tokens.uniq
    b = b_tokens.uniq
    return 0.0 if a.empty? || b.empty?

    matched = a.count do |left|
      b.any? { |right| similar_token?(left, right) }
    end
    matched.to_f / [a.size, b.size].max
  end

  def self.similar_token?(left, right)
    return true if left == right
    return false if left.length < 4 || right.length < 4

    left.start_with?(right) || right.start_with?(left)
  end

  def self.char_similarity(a, b)
    max_len = [a.length, b.length].max
    return 1.0 if max_len.zero?

    1.0 - (levenshtein_distance(a, b).to_f / max_len)
  end

  def self.levenshtein_distance(a, b)
    m = a.length
    n = b.length
    return n if m.zero?
    return m if n.zero?

    prev = (0..n).to_a
    curr = Array.new(n + 1, 0)

    (1..m).each do |i|
      curr[0] = i
      (1..n).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].min
      end
      prev, curr = curr, prev
    end

    prev[n]
  end

  private

  def sync_canonical_products!
    return if user.blank? || source_product.blank? || replacement_product.blank?

    resolver = Local::CanonicalProductResolver.new(user: user)
    source = resolver.call(raw_name: source_product)
    replacement = resolver.call(raw_name: replacement_product)
    return if source.blank? || replacement.blank?

    self.source_canonical_product = source
    self.replacement_canonical_product = replacement
    self.source_product = source.name
    self.replacement_product = replacement.name
  end

  def normalize_products_and_quantities
    src_amount, src_unit, src_scale, src_name = self.class.parse_quantity_from_text(source_product)
    rep_amount, rep_unit, rep_scale, rep_name = self.class.parse_quantity_from_text(replacement_product)

    self.source_product = src_name
    self.replacement_product = rep_name
    self.source_amount = src_amount if src_amount.present?
    self.source_unit = src_unit if src_unit.present?
    self.replacement_amount = rep_amount if rep_amount.present?
    self.replacement_unit = rep_unit if rep_unit.present?

    effective_source_amount = src_amount.presence || self.source_amount
    effective_replacement_amount = rep_amount.presence || self.replacement_amount
    effective_source_scale = src_scale.presence || self.class.unit_scale(self.source_unit)
    effective_replacement_scale = rep_scale.presence || self.class.unit_scale(self.replacement_unit)

    if effective_source_amount.present? && effective_replacement_amount.present? &&
        effective_source_scale.present? && effective_replacement_scale.present? &&
        effective_source_scale.first == effective_replacement_scale.first
      source_base = effective_source_amount.to_f * effective_source_scale.last
      replacement_base = effective_replacement_amount.to_f * effective_replacement_scale.last
      self.amount_multiplier = source_base.positive? ? (replacement_base / source_base) : self.amount_multiplier
    end
  end
end
