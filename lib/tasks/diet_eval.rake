# frozen_string_literal: true

# PDF parser evaluation. Hits the real OpenAI API (costs money).
#
#   bin/rails "diet:golden:draft[my-slug]"                        # corpus/<slug>/diet.pdf -> golden.draft.json
#   bin/rails "diet:golden:draft[fixture-1,spec/fixtures/files/x.pdf]"
#   bin/rails diet:benchmark                                      # current config over the whole corpus
#   bin/rails "diet:benchmark[markdown_per_day\,native_pdf,none\,low,gpt-5.1]"
#   SLUGS=a,b bin/rails diet:benchmark                            # subset of the corpus
namespace :diet do
  namespace :golden do
    desc 'Parse one PDF with the current pipeline and write golden.draft.json for a human to correct'
    task :draft, %i[slug pdf] => :environment do |_, args|
      slug = args.fetch(:slug)
      dir = DietEval::CORPUS_DIR.join(slug)
      FileUtils.mkdir_p(dir)
      pdf = args[:pdf].present? ? Rails.root.join(args[:pdf]) : dir.join('diet.pdf')
      abort "No PDF at #{pdf}" unless File.exist?(pdf)

      pipeline = Chat::Diet::ParsingPipeline.new(pdf.to_s)
      days = pipeline.call
      relative = Pathname(pdf).relative_path_from(dir).to_s
      File.write(dir.join('golden.draft.json'), JSON.pretty_generate(DietEval.golden_from(days, pdf: relative)))
      puts "Wrote #{dir.join('golden.draft.json')} (#{days.size} days, #{pipeline.stats.seconds.round(1)} s). " \
           'Correct it against the PDF, then rename to golden.json.'
    end
  end

  desc 'Run parser configurations over the corpus and print quality / time / cost'
  task :benchmark, %i[strategies efforts models] => :environment do |_, args|
    $stdout.sync = true # progress lines show up live when redirected to a log
    list = ->(value, knob) { value.present? ? value.split(',').map(&:strip) : [DietEval.current(knob)] }
    configs = list.call(args[:strategies], :strategy).product(
      list.call(args[:efforts], :reasoning_effort), list.call(args[:models], :model)
    ).map { |strategy, effort, model| { strategy: strategy, reasoning_effort: effort, model: model }.compact }

    entries = DietEval.entries
    entries.select! { |e| ENV['SLUGS'].split(',').include?(e.slug) } if ENV['SLUGS'].present?
    abort "No corpus entries in #{DietEval::CORPUS_DIR} (need <slug>/golden.json)" if entries.empty?

    out_dir = Rails.root.join('tmp/diet_eval', Time.current.strftime('%Y%m%d-%H%M%S'))
    FileUtils.mkdir_p(out_dir)
    runs = configs.flat_map do |config|
      entries.map do |entry|
        label = config.values.join('/')
        puts "→ #{entry.slug} [#{label}]"
        run = DietEval.run(entry, config)
        File.write(out_dir.join("#{entry.slug}.#{label.tr('/', '.')}.json"),
                   JSON.pretty_generate(run.to_h.merge(stats: run.stats&.to_h)))
        puts "   #{run.error || format('composite %.1f', run.score[:composite])}"
        run
      end
    end

    report = DietEval::Report.new(runs).to_markdown
    File.write(out_dir.join('report.md'), report)
    puts "\n#{report}\nRaw outputs: #{out_dir}"
  end
end
