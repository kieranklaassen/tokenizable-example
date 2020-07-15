class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :products do |t|
      t.string :title
      t.string :description
      t.decimal :price
      t.string :token, null: false

      t.timestamps
    end
    add_index :products, :token
  end
end
