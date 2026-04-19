# frozen_string_literal: true

class DietitianWaitlistEntriesController < ApplicationController
  allow_unauthenticated_access
  layout 'authentication'

  def new
    @dietitian_waitlist_entry = DietitianWaitlistEntry.new
  end

  def create
    @dietitian_waitlist_entry = DietitianWaitlistEntry.new(dietitian_waitlist_entry_params)

    if @dietitian_waitlist_entry.save
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
