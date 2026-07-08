class CreateUpdateUpdatedAtTriggerFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'commons/update_updated_at_with_current_timestamp.sql'
  end

  def down
    drop_function 'update_updated_at_with_current_timestamp'
  end
end
