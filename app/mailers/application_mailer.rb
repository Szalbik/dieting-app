# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'Asystent Diet <no-reply@asystentdiet.pl>'
  layout 'mailer'
  helper ApplicationHelper
end
