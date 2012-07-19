# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


##
# A graph containing ontology information.
#
# @note a Talia3 Ontology is not a Talia3 Resource as it's information
# is not necessarily centered around a single URI.
#
class Talia3::Ontology
  include Talia3::Mixin::HasNamedGraph
  include Talia3::Mixin::HasRepositories
  include Talia3::Mixin::RDFExportable

  set_context :ontology
end # Talia3::Ontology
