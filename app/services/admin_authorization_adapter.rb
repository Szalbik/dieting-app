# frozen_string_literal: true

class AdminAuthorizationAdapter < ActiveAdmin::AuthorizationAdapter
  def authorized?(_action, _subject = nil)
    user&.admin?
  end

  def scope_collection(collection, _action = ActiveAdmin::Authorization::READ)
    user&.admin? ? collection : collection.none
  end
end
