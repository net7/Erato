##
# Seeds file for Talia3 plugin.a

# Default administrator user.
user = Talia3::Auth::User.new(
  :name => 'Default administrator',
  :email => 'admin@localhost',
  :password => 'password',
  :password_confirmation => 'password',
  :admin => true
)
user.skip_confirmation! if user.respond_to? :skip_confirmation!
user.save(:validate => false)

