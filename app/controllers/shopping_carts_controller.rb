# frozen_string_literal: true

class ShoppingCartsController < ApplicationController
  def show
    @shopping_cart = Current.user.shopping_cart
  end
end
