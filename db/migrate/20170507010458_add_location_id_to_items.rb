class AddLocationIdToItems < ActiveRecord::Migration[5.0]
  def change
    add_column :items, :location_id, :integer
  end
end
