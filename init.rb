# Include hook code here
require 'without_callbacks'

ActiveRecord::Base.send(:extend,  CJBottaro::WithoutCallbacks::ClassMethods)
ActiveRecord::Base.send(:include, CJBottaro::WithoutCallbacks::InstanceMethods)