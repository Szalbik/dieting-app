# frozen_string_literal: true

module ShoppingList
  class PolishLemmatizer
    TOKEN_LEMMAS = {
      'jajko' => 'jajko',
      'jajka' => 'jajko',
      'jajek' => 'jajko',
      'jaja' => 'jajko',
      'pomidor' => 'pomidor',
      'pomidory' => 'pomidor',
      'pomidorow' => 'pomidor',
      'marchewka' => 'marchewka',
      'marchewki' => 'marchewka',
      'marchewek' => 'marchewka',
      'ziemniak' => 'ziemniak',
      'ziemniaki' => 'ziemniak',
      'ziemniakow' => 'ziemniak',
      'mleko' => 'mleko',
      'mleka' => 'mleko',
      'kokosowe' => 'kokosowy',
      'kokosowego' => 'kokosowy',
      'kokosowym' => 'kokosowy',
      'kokosowa' => 'kokosowy',
      'kokosowej' => 'kokosowy',
      'kokosowy' => 'kokosowy',
      'naturalny' => 'naturalny',
      'naturalnego' => 'naturalny',
      'naturalna' => 'naturalny',
      'naturalnej' => 'naturalny'
    }.freeze

    def lemma(token)
      normalized = ProductSubstitution.normalize_name(token).delete(' ')
      return normalized if normalized.blank?

      TOKEN_LEMMAS.fetch(normalized, normalized)
    rescue StandardError => e
      Rails.logger.warn("ShoppingList::PolishLemmatizer failed for '#{token}': #{e.message}")
      ProductSubstitution.normalize_name(token).delete(' ')
    end
  end
end
