# frozen_string_literal: true

class AccountMailer < ApplicationMailer
  # Sent to the *previous* address so the owner learns about a takeover attempt.
  def email_changed(user, old_email)
    @user = user
    @old_email = old_email
    mail to: old_email, subject: 'Adres e-mail Twojego konta został zmieniony'
  end
end
