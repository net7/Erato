# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# Talia3 tasks.
#
# @todo i18n
# @todo if init recognizes this is a production environment, 
#   only production stuff should be created.
# @todo refactor so that the functionalities can be used in a web page
#   as well.
#
# @author Riccardo Giomi <giomi@netseven.it>
##
def confirm(text, cautious=true)
  return true if ENV['FORCE']
  puts
  puts text;
  if cautious
    puts %Q(Type "yes" and hit enter to continue, anything else will exit)
    (STDIN.gets.chomp.downcase == 'yes')
  else
    puts %Q(Type anthing except "no" and hit enter to continue)
    (STDIN.gets.chomp.downcase != 'no')
  end
end

def file_copy(source, destination)
  unless File.exists? destination
    # File.copy deprecated in ruby 1.9, using FileUtils.cp
    FileUtils.cp source, destination
    puts "Done."
    puts
  else
    puts "Warning: file #{destination} already exists, cowardly aborting."
    puts "Please remove it and run the task again if you want a pristine file.\n"
    puts
  end  
end

def config_path
  File.join(File.dirname(__FILE__), '..', '..', '..', 'config')
end

def models_path
  File.join(File.dirname(__FILE__), '..', '..', '..', 'app', 'models', 'talia3')
end

namespace :talia3 do
  desc "Initializes Talia3 for use"

  task :init do
    puts
    puts "CONFIGURATION FILES"
    puts
    puts "Initialization will now copy the base configuration file (talia3.yml) in the application config directory."
    puts "The file will not be copied if already present."
    if confirm("Proceed? Skipping this step will not stop the initialization", false)
      puts "Copying..."; puts
      source = File.join(config_path, 'talia3.yml')
      destination = File.join('config', 'talia3.yml');
      file_copy source, destination
      puts "Done."
    end

    puts
    puts "DATABASE MIGRATION"
    puts
    puts "Initialization will now create the database tables and data."
    if confirm("Proceed? This is the last step, skipping it will conclude the process.", false)
      # Migrate only for current environment and test.
      (['test'] << Rails.env).each do |env|
        puts "For environment '#{env}':"
        force = ENV['FORCE'] ? 'FORCE=1' : ''
        system "rake -s RAILS_ENV='#{env}' #{force} talia3:migrate --trace"
        system "rake -s RAILS_ENV='#{env}' #{force} talia3:create_admin" unless env == 'test'
      end
    end
  end

  desc "Prepares the database for the current environment"
  task :migrate => :environment do
    puts
    puts "Migrating database..."
    # require 'devise/orm/active_record'

    Rake::Task['db:migrate'].invoke()
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migrator.migrate File.join(config_path, 'db', 'migrate')
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
    puts "Done."
  end

  desc "Creates a default admin user"
  task :create_admin => :environment do
    unless Rails.env == 'test'
      puts "Importing seeds..."
      begin
        require File.join(config_path, 'db', 'seeds.rb')
      rescue
        puts "Warning: The database protested... please check if the default admin is already present"
      end
      puts "Done."
    else
      puts "Skipped admin creation for test database."
    end
  end

  desc "Clears a Talia3 installation"
  task :cleanse do
    puts
    puts "CONFIGURATION AND DATABASE FILES REMOVAL"
    puts
    puts "Attention: this operation will remove the configuration files and destroy all the databases!"
    puts "To stress how serious this operation is, you will be asked for confirmation twice."
    if confirm("Proceed?") and confirm("Really proceed?")
      puts "Cleansing..."
      puts
      File.delete File.join('config', 'talia3.yml') if File.exists? File.join('config', 'talia3.yml')
      File.delete File.join('db', 'development.sqlite3') if File.exists? File.join('db', 'development.sqlite3')
      File.delete File.join('db', 'test.sqlite3') if File.exists? File.join('db', 'test.sqlite3')
      File.delete File.join('db', 'production.sqlite3') if File.exists? File.join('db', 'production.sqlite3')
      puts "Done."
    end
  end
end
