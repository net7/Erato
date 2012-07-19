# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

Gem::Specification.new do |gem|
  gem.name = %q{talia3}
  gem.version = "0.0.0"
  gem.date = Date.today.to_s

  gem.summary = %q{Basic toolkit for building a Linked Open Data application}
  gem.description = %q{TODO: a long description...}

  gem.authors = ["Riccardo Giomi"]
  gem.email = %q{giomi@netseven.it}
  gem.homepage = %q{TODO: fill after having a git page}

  # LOD content negotiation, also automatically a lot of rdf.rb stuff.
  gem.add_dependency(%q<rack-linkeddata>, ["~> 0.3.0"])
  gem.add_dependency(%q<gettext_i18n_rails>, ["~> 0.2.20"])

  # Provide default Talia3 authentication services.
  gem.add_dependency(%q<oa-oauth>, ["~> 0.2.5"])
  gem.add_dependency(%q<devise>, ["~> 1.3.4"])
end
