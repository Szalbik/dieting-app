# frozen_string_literal: true

class UsersController < ApplicationController
  def update
    if Current.user.update(user_params)
      redirect_to profile_path, notice: 'Your data was updated successfully.'
    else
      flash.now[:error] = 'There was and error.'
      render 'profiles/show', status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :first_name, :about)
  end
end
