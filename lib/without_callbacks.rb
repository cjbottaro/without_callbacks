module CJBottaro # :nodoc:
  
  module WithoutCallbacks # :nodoc:
    
    CALLBACK_LIST = {
      :all_crud => %w[after_create after_destroy after_save after_update before_create before_destroy before_save before_update],
      :all_validation => %w[after_validation after_validation_on_create after_validation_on_update before_validation before_validation_on_create before_validation_on_update],
    }
    CALLBACK_LIST[:all] = CALLBACK_LIST[:all_crud] + CALLBACK_LIST[:all_validation]
    
    def self.check_arguments(klass, callback_names)
      callback_names = [:all] if callback_names.blank?
      
      # expand :all, :all_crud, :all_validation to actual callback names
      callback_names = callback_names.collect{ |callback| CALLBACK_LIST[callback] || callback.to_s }.flatten.uniq
      
      all_callback_names = WithoutCallbacks.get_all_callback_names(klass)
      
      invalid_callbacks = (callback_names.to_set - all_callback_names.to_set).to_a
      raise ArgumentError, "You can't skip callbacks that don't exist: " + invalid_callbacks.join(', ') unless invalid_callbacks.blank?
      callback_names
    end
    
    def self.get_all_callback_names(klass)
      if klass.respond_to?(:before_save_callback_chain)
        callback_names = get_all_callback_names__chain(klass)
      else
        callback_names = get_all_callback_names__array(klass)
      end
      ActiveRecord::Callbacks::CALLBACKS + callback_names
    end
    
    def self.get_all_callback_names__chain(klass)
      klass.class_eval do
        ActiveRecord::Callbacks::CALLBACKS.inject([]) do |memo, callback_name|
          chain = send("#{callback_name}_callback_chain")
          memo += chain.inject([]) { |memo, callback| memo << callback.method.to_s if callback.method.instance_of?(Symbol); memo }
          memo
        end
      end
    end
    
    def self.get_all_callback_names__array(klass)
      klass.class_eval do
        ActiveRecord::Callbacks::CALLBACKS.inject([]) do |memo, callback_name|
          chain = read_inheritable_attribute(callback_name.to_sym)
          memo += chain.inject([]) { |memo, callback| memo << callback.to_s } unless chain.blank?
          memo
        end
      end
    end
    
    def self.backup_chains(klass)
      if klass.respond_to?(:before_save_callback_chain)
        backup_chains__chain(klass)
      else
        backup_chains__array(klass)
      end
    end
    
    def self.backup_chains__chain(klass)
      chains = {}
      klass.class_eval do
        ActiveRecord::Callbacks::CALLBACKS.each do |chain_name|
          chains[chain_name] = send("#{chain_name}_callback_chain")
        end
      end
      chains
    end
    
    def self.backup_chains__array(klass)
      chains = {}
      klass.class_eval do
        ActiveRecord::Callbacks::CALLBACKS.each do |chain_name|
          chain = read_inheritable_attribute(chain_name.to_sym)
          chains[chain_name] = chain.collect{ |callback_name| callback_name.to_s } unless chain.blank?
        end
      end
      chains
    end
    
    def self.backup_methods(klass)
      methods = {}
      klass.class_eval do
        ActiveRecord::Callbacks::CALLBACKS.each do |method_name|
          if method_defined?(method_name.to_sym)
            methods[method_name] = instance_method(method_name.to_sym)
          end
        end
      end
      methods
    end
    
    def self.alter_chains(klass, callback_names)
      if klass.respond_to?(:before_save_callback_chain)
        alter_chains__chain(klass, callback_names)
      else
        alter_chains__array(klass, callback_names)
      end
    end
    
    def self.alter_chains__chain(klass, callback_names)
      klass.class_eval do
        callback_names.each do |callback_name|
          if ActiveRecord::Callbacks::CALLBACKS.include?(callback_name)
            instance_variable_set("@#{callback_name}_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
          else
            ActiveRecord::Callbacks::CALLBACKS.each do |chain_name|
              chain = send("#{chain_name}_callback_chain").reject{ |callback| callback.method.instance_of?(Symbol) and callback.method.to_s == callback_name }
              instance_variable_set("@#{chain_name}_callbacks", chain)
            end
          end
        end
      end
    end
    
    def self.alter_chains__array(klass, callback_names)
      klass.class_eval do
        callback_names.each do |callback_name|
          if ActiveRecord::Callbacks::CALLBACKS.include?(callback_name)
            write_inheritable_attribute(callback_name.to_sym, [])
          else
            ActiveRecord::Callbacks::CALLBACKS.each do |chain_name|
              chain = read_inheritable_attribute(chain_name.to_sym)
              unless chain.blank?
                chain = chain.reject{ |name| name.to_s == callback_name }
                write_inheritable_attribute(chain_name.to_sym, chain)
              end
            end
          end
        end
      end
    end
    
    def self.alter_methods(klass, method_names)
      klass.class_eval do
        method_names.each do |method_name|
          if method_defined?(method_name.to_sym) and ActiveRecord::Callbacks::CALLBACKS.include?(method_name)
            define_method(method_name.to_sym) {}
          end
        end
      end
    end
    
    def self.restore_chains(klass, backed_up_chains)
      if klass.respond_to?(:before_save_callback_chain)
        klass.class_eval do
          backed_up_chains.each { |chain_name, chain| instance_variable_set("@#{chain_name}_callbacks", chain) }
        end
      else
        klass.class_eval do
          backed_up_chains.each { |chain_name, chain| write_inheritable_attribute(chain_name.to_sym, chain) }
        end
      end
    end
    
    def self.restore_methods(klass, backed_up_methods)
      klass.class_eval do
        backed_up_methods.each { |method_name, method| define_method(method_name.to_sym, method) }
      end
    end
    
    def self.backup(klass, callbacks_to_skip) # :nodoc:
      methods_to_skip = {}
      klass.class_eval do
        callbacks_to_skip.each do |callback|
          methods_to_skip[callback] = { :symbols => nil, :method => nil }
        
          # backup the symbols list
          if CALLBACK_LIST[:all].include?(callback)
            methods_to_skip[callback][:symbols] = read_inheritable_attribute(callback.to_sym)
            write_inheritable_attribute(callback.to_sym, nil)
          end
        
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
          write_inheritable_attribute(callback.to_sym, symbols) unless symbols.blank?
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
      def without_callbacks(*callback_names, &block)
        raise ArgumentError, "block required" unless block_given?
        callback_names = WithoutCallbacks.check_arguments(self, callback_names)
        
        backed_up_chains = WithoutCallbacks.backup_chains(self)
        backed_up_methods = WithoutCallbacks.backup_methods(self)
        
        WithoutCallbacks.alter_chains(self, callback_names)
        WithoutCallbacks.alter_methods(self, callback_names)
        
        begin
          yield self # this will (and needs to) be the return value of this method
        rescue Exception => e
          raise
        ensure
          WithoutCallbacks.restore_chains(self, backed_up_chains)
          WithoutCallbacks.restore_methods(self, backed_up_methods)
        end
        
      end
      
    end
    
    module InstanceMethods
      
      # All specified callbacks will not be called inside the given block.
      #  m = MyModel.new
      #  m.without_callbacks do |o|
      #    o.save
      #  end
      def without_callbacks(*callback_names, &block)
        raise ArgumentError, "block required" unless block_given?
        self.class.without_callbacks(*callback_names) do |klass|
          yield self
        end
      end
      
    end # module InstanceMethods
    
  end
  
end