# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


module Talia3::Metal
  ##
  # API 404 (not found) handler.
  #
  class HTTP404 < Talia3::Metal::Base
    def self.call(env)
      [404, text_plain, ["Not Found"]]
    end
  end
end
