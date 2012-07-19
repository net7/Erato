FastGettext.add_text_domain 'app', :path => File.join(Talia3.root, 'locale'), :type => :po
# FastGettext wants the locales to be strings, and the :none language makes no sense to it, of course.
FastGettext.default_available_locales = Talia3.locales.reject {|l| l == :none}.map {|l| l.to_s}
FastGettext.default_text_domain = 'app'
