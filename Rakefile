# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

# NOTE: removed test task for now, until I decide for 
# a convienient testing policy.

desc 'Generate documentation for the talia3 plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Talia3'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'talia3'
    gem.summary = 'Basic toolkit for building a Linked Open Data application'
    gem.description = %Q(TODO: a long description...)
    gem.authors = ["Riccardo Giomi"]
    gem.email = "giomi@netseven.it"
    gem.homepage = "TODO: fill after having a git page"
    gem.add_dependency 'rdf',           '>= 0.3.0'
    gem.add_dependency 'rdf-raptor',    '>= 0.4.1'
    gem.add_dependency 'rdf-json',      '>= 0.3.0'
    gem.add_dependency 'rdf-trix',      '>= 0.3.0'
  end
end