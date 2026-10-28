class AddPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    # NULL のユーザー（system 等）はログインできない
    add_column :users, :password_digest, :text

    # name をログインIDとして使う
    add_index :users, :name, unique: true
  end
end
