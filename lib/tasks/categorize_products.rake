# frozen_string_literal: true

# Uzupełnianie kategorii dla produktów bez ProductCategory:
#
#   Wywołuj przez bin/rake (w Dockerze `bin/rails zadanie` często zwraca UnrecognizedCommand).
#
#   USER_EMAIL=ty@example.com bin/rake products:propagate_missing_categories
#
#   bin/rake products:propagate_canonical_categories
#   bin/rake products:propagate_same_name_categories
#   bin/rake products:categorize_common
#   bin/rake products:categorize_all   # + worker kolejki
#
# Jeśli rake zgłasza „Don't know how to build task”: w kontenerze sprawdź
#   ls -la lib/tasks/categorize_products.rake
# i przebuduj obraz po wdrożeniu tego pliku z repozytorium.
#
module ProductsCategoryRake
  module_function

  def products_scope_for_rake
    scope = Product.all
    if ENV['USER_EMAIL'].present?
      user = User.find_by(email_address: ENV['USER_EMAIL'])
      abort "Nie znaleziono użytkownika: #{ENV['USER_EMAIL']}" unless user

      scope = scope.joins(meal: { diet_set: :diet }).where(diets: { user_id: user.id })
      puts "Zakres: produkty z diet użytkownika #{ENV['USER_EMAIL']}"
    else
      puts 'Zakres: wszystkie produkty'
    end
    scope
  end

  def uncategorized_products_scope
    products_scope_for_rake.left_joins(:product_category).where(product_categories: { id: nil })
  end

  # 1) Inny produkt z tym samym canonical_product_id i już z ProductCategory.
  # 2) Starsze wpisy: mają kategorię, ale canonical_product_id = nil — dopasowanie po nazwie
  #    kanonicznej (ta sama etykieta co CanonicalProduct.name).
  def find_canonical_category_donor(product)
    canon = product.canonical_product
    return [nil, nil] unless canon

    donor = Product.joins(:product_category)
      .where(canonical_product_id: canon.id)
      .where.not(id: product.id)
      .first
    return [:fk, donor] if donor&.category

    label = canon.name.to_s.strip.downcase
    return [nil, nil] if label.blank?

    # Dokładna nazwa / baza jak etykieta kanonu (starsze produkty bez FK).
    donor = Product.joins(:product_category)
      .where(canonical_product_id: nil)
      .where.not(id: product.id)
      .where(
        <<~SQL.squish,
          LOWER(TRIM(COALESCE(NULLIF(TRIM(products.base_product_name), ''), products.name))) = :label
        SQL
        { label: label }
      )
      .first
    return [:name_exact, donor] if donor&.category

    # Prefiks: kanon "Jogurt naturalny" → skategoryzowany "Jogurt naturalny 2% ..."
    if label.length >= 3
      like_pattern = "#{ActiveRecord::Base.sanitize_sql_like(label)}%"
      donor = Product.joins(:product_category)
        .where(canonical_product_id: nil)
        .where.not(id: product.id)
        .where("LOWER(TRIM(products.name)) LIKE LOWER(?)", like_pattern)
        .order(Arel.sql('LENGTH(products.name) ASC'))
        .first
      return [:name_prefix, donor] if donor&.category
    end

    [nil, nil]
  end
end

namespace :products do
  desc 'Skopiuj kategorię z innego produktu z tym samym kanonem (FK lub ta sama nazwa kanoniczna u skategoryzowanych bez FK)'
  task propagate_canonical_categories: :environment do
    scope = ProductsCategoryRake.uncategorized_products_scope.where.not(canonical_product_id: nil)
    total = scope.count
    puts "Produkty bez kategorii z ustawionym canonical: #{total}"
    copied = 0
    via_fk = 0
    via_name_exact = 0
    via_name_prefix = 0

    scope.find_each do |product|
      source, donor = ProductsCategoryRake.find_canonical_category_donor(product)
      next unless donor&.category

      pc = donor.product_category
      ProductCategory.create!(
        product: product,
        category: donor.category,
        state: pc.state
      )
      copied += 1
      case source
      when :fk then via_fk += 1
      when :name_exact then via_name_exact += 1
      when :name_prefix then via_name_prefix += 1
      end
      puts "  #{product.id} #{product.name.truncate(60)} ← #{source} → #{donor.category.name}" if copied <= 30
    rescue StandardError => e
      puts "  Błąd produkt #{product.id}: #{e.message}"
    end

    puts "Skopiowano kategorię dla #{copied} produktów " \
         "(FK: #{via_fk}, nazwa=kanon: #{via_name_exact}, prefiks nazwy: #{via_name_prefix})."
  end

  desc 'Skopiuj kategorię z innego produktu o tej samej nazwie (LOWER, synchronicznie)'
  task propagate_same_name_categories: :environment do
    scope = ProductsCategoryRake.uncategorized_products_scope
    total = scope.count
    puts "Produkty bez kategorii (sprawdzanie dopasowania po nazwie): #{total}"
    copied = 0

    scope.find_each do |product|
      next if product.name.blank?

      donor = Product.joins(:product_category)
        .where('LOWER(products.name) = ?', product.name.downcase)
        .where.not(id: product.id)
        .first
      next unless donor&.category

      pc = donor.product_category
      ProductCategory.create!(
        product: product,
        category: donor.category,
        state: pc.state
      )
      copied += 1
      puts "  #{product.id} #{product.name.truncate(60)} ← ta sama nazwa co #{donor.id} → #{donor.category.name}"
    rescue StandardError => e
      puts "  Błąd produkt #{product.id}: #{e.message}"
    end

    puts "Skopiowano kategorię dla #{copied} produktów."
  end

  desc 'Najpierw canonical, potem ta sama nazwa (USER_EMAIL= opcjonalnie)'
  task propagate_missing_categories: :environment do
    %w[products:propagate_canonical_categories products:propagate_same_name_categories].each do |name|
      Rake::Task[name].reenable
      Rake::Task[name].invoke
    end
  end

  desc 'Manually categorize common products to train the classifier'
  task categorize_common: :environment do
    puts 'Categorizing common products...'

    # Common product categorizations
    categorizations = {
      'jogurt naturalny' => 'Nabiał',
      'mleko' => 'Nabiał',
      'ser' => 'Nabiał',
      'twaróg' => 'Nabiał',
      'kefir' => 'Nabiał',
      'śmietana' => 'Nabiał',
      'jajka' => 'Nabiał',
      'masło' => 'Nabiał',
      'chleb' => 'Pieczywo',
      'bułka' => 'Pieczywo',
      'bagietka' => 'Pieczywo',
      'tosty' => 'Pieczywo',
      'jabłko' => 'Owoce',
      'banan' => 'Owoce',
      'pomarańcza' => 'Owoce',
      'gruszka' => 'Owoce',
      'truskawki' => 'Owoce',
      'marchewka' => 'Warzywa',
      'pomidor' => 'Warzywa',
      'ogórek' => 'Warzywa',
      'cebula' => 'Warzywa',
      'ziemniaki' => 'Warzywa',
      'kurczak' => 'Mięso i Ryby',
      'indyk' => 'Mięso i Ryby',
      'wołowina' => 'Mięso i Ryby',
      'łosoś' => 'Mięso i Ryby',
      'tuńczyk' => 'Mięso i Ryby',
      'szynka' => 'Wędliny',
      'kiełbasa' => 'Wędliny',
      'salami' => 'Wędliny',
      'woda' => 'Napoje',
      'herbata' => 'Napoje',
      'kawa' => 'Napoje',
      'sok' => 'Napoje',
      'ryż' => 'Produkty zbożowe',
      'makaron' => 'Produkty zbożowe',
      'kasza' => 'Produkty zbożowe',
      'płatki owsiane' => 'Produkty zbożowe',
      'musli' => 'Produkty zbożowe',
      'orzechy włoskie' => 'Orzechy',
      'migdały' => 'Orzechy',
      'pistacje' => 'Orzechy',
      'sól' => 'Przyprawy',
      'pieprz' => 'Przyprawy',
      'bazylia' => 'Przyprawy',
      'oregano' => 'Przyprawy'
    }

    categorized_count = 0

    categorizations.each do |product_name, category_name|
      # Find products with similar names
      products = Product.where('LOWER(name) LIKE ?', "%#{product_name.downcase}%")

      products.each do |product|
        # Skip if already categorized
        next if product.category.present?

        category = Category.find_by(name: category_name)
        next unless category

        # Create product category
        ProductCategory.create!(
          product: product,
          category: category,
          state: true
        )

        categorized_count += 1
        puts "Categorized: #{product.name} -> #{category_name}"
      end
    end

    puts "Categorized #{categorized_count} products"

    # Now train the classifier
    puts 'Training classifier...'
    Classifier::Category.train!
    puts 'Classifier trained successfully!'
  end

  desc 'Categorize all uncategorized products using the trained classifier'
  task categorize_all: :environment do
    puts 'Categorizing all uncategorized products...'

    uncategorized_products = Product.includes(:product_category).where(product_categories: { id: nil })
    total = uncategorized_products.count

    puts "Found #{total} uncategorized products"

    categorized_count = 0

    uncategorized_products.find_each do |product|
      product.categorize_if_needed
      categorized_count += 1
      puts "Queued for categorization: #{product.name}"
    rescue StandardError => e
      puts "Error categorizing #{product.name}: #{e.message}"
    end

    puts "Queued #{categorized_count} products for categorization"
  end
end
