# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCartInvitation, type: :model do
  describe '#accept!' do
    it 'connects both users to one active shopping cart and syncs their meal items' do
      inviter = create(:user)
      invitee = create(:user)

      inviter_diet = create(:diet, user: inviter)
      inviter_set = create(:diet_set, diet: inviter_diet)
      inviter_meal = create(:meal, diet_set: inviter_set)
      inviter_plan = create(:diet_set_plan, diet_set: inviter_set, diet: inviter_diet, date: Date.current)
      inviter_meal_plan = create(:meal_plan, diet_set_plan: inviter_plan, meal: inviter_meal, selected_for_cart: true)
      inviter_product = create(:product, meal: inviter_meal, diet_set: inviter_set, name: 'Owsianka')

      invitee_diet = create(:diet, user: invitee)
      invitee_set = create(:diet_set, diet: invitee_diet)
      invitee_meal = create(:meal, diet_set: invitee_set)
      invitee_plan = create(:diet_set_plan, diet_set: invitee_set, diet: invitee_diet, date: Date.current)
      invitee_meal_plan = create(:meal_plan, diet_set_plan: invitee_plan, meal: invitee_meal, selected_for_cart: true)
      invitee_product = create(:product, meal: invitee_meal, diet_set: invitee_set, name: 'Jajka')

      create(:shopping_cart_item, shopping_cart: inviter.owned_shopping_cart, product: inviter_product,
                                  meal_plan: inviter_meal_plan)
      create(:shopping_cart_item, shopping_cart: invitee.owned_shopping_cart, product: invitee_product,
                                  meal_plan: invitee_meal_plan)
      invitation = create(:shopping_cart_invitation, inviter: inviter, invitee: invitee)

      invitation.accept!

      expect(invitation.reload).to be_accepted
      expect(inviter.reload.active_shopping_cart).to eq(inviter.owned_shopping_cart)
      expect(invitee.reload.active_shopping_cart).to eq(inviter.owned_shopping_cart)

      shared_product_ids = inviter.owned_shopping_cart.shopping_cart_items.pluck(:product_id)
      expect(shared_product_ids).to include(inviter_product.id, invitee_product.id)
    end
  end

  describe '#revoke!' do
    it 'disconnects users from a shared cart and restores personal cart syncing' do
      inviter = create(:user)
      invitee = create(:user)

      inviter_diet = create(:diet, user: inviter)
      inviter_set = create(:diet_set, diet: inviter_diet)
      inviter_meal = create(:meal, diet_set: inviter_set)
      inviter_plan = create(:diet_set_plan, diet_set: inviter_set, diet: inviter_diet, date: Date.current)
      create(:meal_plan, diet_set_plan: inviter_plan, meal: inviter_meal, selected_for_cart: true)
      inviter_product = create(:product, meal: inviter_meal, diet_set: inviter_set, name: 'Kasza')

      invitee_diet = create(:diet, user: invitee)
      invitee_set = create(:diet_set, diet: invitee_diet)
      invitee_meal = create(:meal, diet_set: invitee_set)
      invitee_plan = create(:diet_set_plan, diet_set: invitee_set, diet: invitee_diet, date: Date.current)
      create(:meal_plan, diet_set_plan: invitee_plan, meal: invitee_meal, selected_for_cart: true)
      invitee_product = create(:product, meal: invitee_meal, diet_set: invitee_set, name: 'Twarog')

      inviter.owned_shopping_cart.custom_cart_items.create!(name: 'Papier', quantity: 1, unit: 'szt')

      invitation = create(:shopping_cart_invitation, inviter: inviter, invitee: invitee)
      invitation.accept!

      invitation.revoke!(actor: inviter)

      expect(invitation.reload).to be_revoked
      expect(inviter.reload.active_shopping_cart).to eq(inviter.owned_shopping_cart)
      expect(invitee.reload.active_shopping_cart).to eq(invitee.owned_shopping_cart)
      expect(inviter.owned_shopping_cart.shopping_cart_items.pluck(:product_id)).to contain_exactly(inviter_product.id)
      expect(invitee.owned_shopping_cart.shopping_cart_items.pluck(:product_id)).to contain_exactly(invitee_product.id)
      expect(invitee.owned_shopping_cart.custom_cart_items.pluck(:name)).to include('Papier')
    end
  end
end
