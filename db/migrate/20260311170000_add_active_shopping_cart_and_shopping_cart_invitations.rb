# frozen_string_literal: true

class AddActiveShoppingCartAndShoppingCartInvitations < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:users, :active_shopping_cart_id)
      add_reference :users, :active_shopping_cart, foreign_key: { to_table: :shopping_carts }
    end

    unless table_exists?(:shopping_cart_invitations)
      create_table :shopping_cart_invitations do |t|
        t.references :inviter, null: false, foreign_key: { to_table: :users }
        t.references :invitee, null: false, foreign_key: { to_table: :users }
        t.integer :status, null: false, default: 0
        t.datetime :accepted_at
        t.datetime :responded_at
        t.datetime :revoked_at
        t.timestamps
      end
    end

    unless index_exists?(:shopping_cart_invitations, %i[inviter_id invitee_id status], name: 'idx_cart_invites_on_pair_and_status')
      add_index :shopping_cart_invitations,
                %i[inviter_id invitee_id status],
                name: 'idx_cart_invites_on_pair_and_status'
    end
    add_index :shopping_cart_invitations, :status unless index_exists?(:shopping_cart_invitations, :status)

    unless index_exists?(:shopping_carts, :user_id, unique: true)
      remove_index :shopping_carts, :user_id if index_exists?(:shopping_carts, :user_id)
      add_index :shopping_carts, :user_id, unique: true
    end

    execute <<~SQL.squish
      UPDATE users
      SET active_shopping_cart_id = shopping_carts.id
      FROM shopping_carts
      WHERE shopping_carts.user_id = users.id
    SQL

    change_column_null :users, :active_shopping_cart_id, false if column_exists?(:users, :active_shopping_cart_id)
  end

  def down
    remove_index :shopping_carts, :user_id if index_exists?(:shopping_carts, :user_id)
    add_index :shopping_carts, :user_id unless index_exists?(:shopping_carts, :user_id)
    drop_table :shopping_cart_invitations if table_exists?(:shopping_cart_invitations)
    remove_reference :users, :active_shopping_cart, foreign_key: { to_table: :shopping_carts } if column_exists?(:users, :active_shopping_cart_id)
  end
end
