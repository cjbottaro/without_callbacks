module CJBottaro # :nodoc:
  
  module WithoutCallbacks # :nodoc:
    
    CALLBACK_LIST = {
      :all_crud => %w[after_create after_destroy after_save after_update before_create before_destroy before_save before_update],
      :all_validation => %w[after_validation after_validation_on_create after_validation_on_update before_validation before_validation_on_create before_validation_on_update],
    }
    CALLBACK_LIST[:all] = CALLBACK_LIST[:all_crud] + CALLBACK_LIST[:all_validation]
    
    def self.backup(klass, callbacks_to_skip) # :nodoc:
      methods_to_skip = {}
      klass.class_eval do
        callbacks_to_skip.each do |callback|
          methods_to_skip[callback] = { :symbols => nil, :method => nil }
        
          # backup the symbols list
          methods_to_skip[callback][:symbols] = read_inheritable_attribute(callback.to_sym)
          write_inheritable_attribute(callback.to_sym, nil)
        
          # backup the method
          methods_to_skip[callback][:method] = instance_method(callback.to_sym)
          define_method(callback.to_sym) {}
        end
      end
      methods_to_skip
    end
    
    def self.restore(klass, methods_to_skip) # :nodoc:
      klass.class_eval do
        methods_to_skip.each do |callback, symbols_method|
          symbols, method = symbols_method[:symbols], symbols_method[:method]
          write_inheritable_attribute(callback.to_sym, symbols)
          define_method(callback.to_sym, method) unless method.blank?
        end
      end
    end
    
    module ClassMethods
      
      # All specified callbacks will not be call inside the given block.
      #  o = nil
      #  MyModel.without_callbacks do |klass|
      #    o = klass.create
      #  end
      def without_callbacks(callback_to_skip = :all, *args, &block)
        raise ArgumentError, "block required" unless block_given?
        
        callbacks_to_skip = [callback_to_skip] + args
        callbacks_to_skip = callbacks_to_skip.collect{ |callback| CALLBACK_LIST[callback] || callback.to_s }.flatten.uniq
        invalid_callbacks = (callbacks_to_skip.to_set - CALLBACK_LIST[:all].to_set).to_a
        raise ArgumentError, "You can't skip callbacks that don't exist: " + invalid_callbacks.join(', ') unless invalid_callbacks.blank?
        
        methods_to_skip = WithoutCallbacks.backup(self, callbacks_to_skip)
        
        begin
          yield self
        rescue Exception => e
          raise
        ensure
          WithoutCallbacks.restore(self, methods_to_skip)
        end
        
      end
      
    end
    
    module InstanceMethods
      
      # All specified callbacks will not be called inside the given block.
      #  m = MyModel.new
      #  m.without_callbacks do |o|
      #    o.save
      #  end
      def without_callbacks(callback_to_skip = :all, *args, &block)
        raise ArgumentError, "block required" unless block_given?
        self.class.without_callbacks(callback_to_skip, *args) do |klass|
          yield self
        end
      end
      
    end # module InstanceMethods
    
  end
  
end