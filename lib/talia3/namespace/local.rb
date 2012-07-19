# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


class Talia3::Namespace
  ##
  # Special namespace for uris local to the current application.
  #
  # Uses Talia3 configuration to determine the base uri. Defaults to
  # "http://localhost/" if no configuration is found.
  #
  # @example Talia::N::LOCAL.resource1
  class LOCAL < Talia3::Namespace
    register :local, (Talia3.config(:base_uri) ? Talia3.config(:base_uri) : "http://localhost/")

    ##
    # Initializes this namespace.
    #
    # @note Parameters should be ignored for explicit namespaces.
    #
    # @param [Symbol] ignored
    # @param [String] ignored
    # @return [Talia3::Namespace::LOCAL]
    def initialize(prefix=nil, uri_s=nil)
      @uri = Talia3.config(:base_uri) ? Talia3.config(:base_uri) : "http://localhost/"
      @prefix = :local
    end
  end
end # class Talia3::Namespace
