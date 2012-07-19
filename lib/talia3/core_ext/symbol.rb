# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.


class Symbol
  def to_uri
    Talia3::URI.from_key self
  end

  def talia3_class
    to_uri.to_class
  end
end
