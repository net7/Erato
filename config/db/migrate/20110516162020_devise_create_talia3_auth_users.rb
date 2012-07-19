# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


class DeviseCreateTalia3AuthUsers < ActiveRecord::Migration
  def self.up
    create_table :talia3_auth_users do |t|
      t.string  :name
      t.boolean :admin, :default => false

      t.database_authenticatable :null => false
      t.recoverable
      t.rememberable
      t.trackable
      t.confirmable
      t.lockable :lock_strategy => :failed_attempts, :unlock_strategy => :both
      t.token_authenticatable

      t.timestamps
    end

    add_index :talia3_auth_users, :reset_password_token, :unique => true
    add_index :talia3_auth_users, :confirmation_token,   :unique => true
    add_index :talia3_auth_users, :unlock_token,         :unique => true
    add_index :talia3_auth_users, :authentication_token, :unique => true
  end

  def self.down
    drop_table :talia3_auth_users
  end
end
