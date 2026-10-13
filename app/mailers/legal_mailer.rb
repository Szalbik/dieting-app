# frozen_string_literal: true

# Notice of a new Regulamin / Polityka prywatności version, ≥14 days before it binds existing
# accounts (Regulamin §10 ust. 3, art. 384¹ KC). Sent by LegalDocuments.notify_change!.
class LegalMailer < ApplicationMailer
  def terms_change(user)
    @effective_on = LegalDocuments::EFFECTIVE_ON.strftime('%d.%m.%Y')
    mail to: user.email_address, subject: "Zmiany w Regulaminie i Polityce prywatności od #{@effective_on}"
  end
end
