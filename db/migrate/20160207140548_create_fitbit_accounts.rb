class CreateFitbitAccounts < ActiveRecord::Migration
  def change
    create_table :fitbit_accounts do |t|
      t.string :email
      t.string :token
      t.string :secret
      t.string :fitbit_id
      t.string :study_id
      t.integer :phone_number
      t.integer :weekly_average
      t.integer :steps_yesterday
      t.integer :goal_reached
      t.string :activity_level
      t.datetime :last_sync_time
      t.datetime :last_reminder_message
      t.integer :week
      t.datetime :activation_date
      t.timestamps
    end
  end
end