require File.dirname(__FILE__) + '/../../../../test/test_helper'

ActiveRecord::Base.connection.create_table :without_callbacks_test_models, :force => true do |t|
end

class WithoutCallbacksTestModel < ActiveRecord::Base
  attr_reader :flags
  after_save :after_save_callback
  
  def after_initialize
    reset
  end
  
  def reset
    @flags = {}
  end
  
  def set(sym)
    @flags[sym] = true
  end
  
  def set?(sym)
    !!@flags[sym]
  end
  
  def before_save
    @flags[:before_save] = true
  end
  
  def after_save_callback
    @flags[:after_save_callback] = true
  end
  
end

class Derived < WithoutCallbacksTestModel
  def before_save
    @flags[:before_save_derived] = true
    super
  end
end

class WithoutCallbacksTest < Test::Unit::TestCase

  def test_instance
    r = WithoutCallbacksTestModel.new
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r.reset
    r.without_callbacks(:all) { |o| o.save }
    assert_equal false, r.set?(:before_save)
    assert_equal false, r.set?(:after_save_callback)
    
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
  end
  
  def test_class
    r = WithoutCallbacksTestModel.new
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r.reset
    WithoutCallbacksTestModel.without_callbacks(:all) { r.save }
    assert_equal false, r.set?(:before_save)
    assert_equal false, r.set?(:after_save_callback)
    
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
  end
  
  def test_create
    r = WithoutCallbacksTestModel.create
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r = nil
    WithoutCallbacksTestModel.without_callbacks(:all) { r = WithoutCallbacksTestModel.create }
    assert_equal false, r.set?(:before_save)
    assert_equal false, r.set?(:after_save_callback)
    
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
  end
  
  def test_named
    r = WithoutCallbacksTestModel.new
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r.reset
    r.without_callbacks(:before_save) { |o| o.save }
    assert_equal false, r.set?(:before_save)
    assert_equal true, r.set?(:after_save_callback)
    
    r.reset
    r.without_callbacks(:after_save) { |o| o.save }
    assert_equal true, r.set?(:before_save)
    assert_equal false, r.set?(:after_save_callback)
    
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
  end
  
  def test_derived
    r = WithoutCallbacksTestModel.new
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    d = Derived.new
    d.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r.reset
    d.reset
    Derived.without_callbacks(:all) do
      r.save
      d.save
    end
    assert_equal true, r.set?(:before_save)
    assert_equal true, r.set?(:after_save_callback)
    assert_equal false, d.set?(:before_save)
    assert_equal false, d.set?(:after_save_callback)
    
    r.save
    d.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    assert d.set?(:before_save)
    assert d.set?(:after_save_callback)
  end
  
  def test_granular
    r = WithoutCallbacksTestModel.new
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
    
    r.reset
    r.without_callbacks(:after_save_callback) { |o| o.save }
    assert_equal true, r.set?(:before_save)
    assert_equal false, r.set?(:after_save_callback)
    
    r.save
    assert r.set?(:before_save)
    assert r.set?(:after_save_callback)
  end
  
end
