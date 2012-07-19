# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Talia3 basic user.
#
# Uses Devise.
class Talia3::Auth::User < ActiveRecord::Base
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable,
         :omniauthable,
         :lockable,
         :timeoutable

  devise :token_authenticatable if Talia3.api_enabled?
  devise :confirmable           if Talia3.user_emails_enabled?

  attr_accessible :name, :admin, :email, :password, :password_confirmation, :remember_me

  def admin?
    !!self.admin
  end
end # class Talia3::Auth::User
