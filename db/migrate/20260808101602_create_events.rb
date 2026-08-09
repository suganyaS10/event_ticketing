class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_enum :event_status, [ 'draft', 'published' ]

    create_table :events do |t|
      t.string :name, null: false
      t.string :venue, null: false
      t.text :description
      t.string :short_description
      t.enum :status, enum_type: :event_status, null: false, default: 'draft'
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.timestamps
    end

    add_index :events, [ :status, :start_time ]
  end
end
