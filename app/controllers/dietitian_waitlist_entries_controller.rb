# frozen_string_literal: true

class DietitianWaitlistEntriesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to new_dietitian_waitlist_entry_url, alert: 'Try again later.' }
  layout 'authentication'

  def new
    @dietitian_waitlist_entry = DietitianWaitlistEntry.new
  end

  def create
    @dietitian_waitlist_entry = DietitianWaitlistEntry.new(dietitian_waitlist_entry_params)

    # A repeat application answers like a first one, so the form cannot be used to check who applied.
    if @dietitian_waitlist_entry.save || @dietitian_waitlist_entry.errors.of_kind?(:email_address, :taken)
      redirect_to new_dietitian_waitlist_entry_path,
                  notice: 'Thanks. We will review your application and reach out to schedule a demo call.'
    else
      flash.now[:alert] = 'Please check the form and try again.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def dietitian_waitlist_entry_params
    params.require(:dietitian_waitlist_entry).permit(:first_name, :email_address, :company_name)
  end
end
