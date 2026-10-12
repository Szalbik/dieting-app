# frozen_string_literal: true

namespace :email do
  desc 'Send a Hello World email through Resend: bin/rails "email:test[to@example.com]"'
  task :test, [:to] => :environment do |_task, args|
    abort 'Usage: bin/rails "email:test[to@example.com]"' if args[:to].blank?

    message = ApplicationMailer.new.mail(
      to: args[:to],
      subject: 'Hello World',
      body: '<p>Congrats on sending your <strong>first email</strong>!</p>',
      content_type: 'text/html'
    )
    # Force Resend even in dev (whose default delivery sends nothing) and surface API errors.
    message.delivery_method(Resend::Mailer)
    message.raise_delivery_errors = true
    message.deliver

    puts "Sent to #{args[:to]} from #{message.from.join}"
  end
end
