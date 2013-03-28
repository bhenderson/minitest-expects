require 'minitest/unit'

class MiniTest::Expects
  VERSION = '0.1.0'

  module LifeCycleHooks
    def before_setup
      MiniTest::Expects.instances.clear
      super
    end

    def after_teardown
      super
      # MiniTest::Expects.teardown
    end
  end

  def self.instances
    @instances ||= []
  end

  def self.teardown
    @instances.each do |mocker|
      mocker.restore
    end
  end

  def initialize subject
    @subject = subject

    @any_instance = false
    @count = 0
    @meth = nil
    @restored = true
    @returns = nil
    @with = []

    self.class.instances << self
  end

  def any_instance
    @any_instance = true
    self
  end

  def expects name
    restore
    @meth = name

    # copied from MiniTest::Mock stub()
    if @subject.respond_to? name and
      not @subject.methods.map(&:to_s).include? name.to_s then
      metaclass.send :define_method, name do |*args|
        super(*args)
      end
    end

    metaclass.__send__ :alias_method, new_meth_name, @meth

    mocker = self
    metaclass.__send__ :define_method, name do |*args, &block|
      mocker.match?(*args, &block)
    end

    @restored = false

    self
  end

  def match? *args
    @count -= 1

    flunk "called too many times" unless
      @count != 0

    pass = if Proc === @with
             msg = "arguments block returned false"
             @with.call(*args)
           else
             msg = "wrong arguments #{args.inspect}\nexpected #{@with.inspect}"
             @with.size == args.size and
               @with.each_with_index.all? do |p, i|
                 val = args[i]
                 p == val or p === val
               end
           end

    flunk msg unless pass

    yield @yields if block_given?
    @returns
  end

  def never
    times 0
  end

  def once
    times 1
  end

  def restore
    return if @restored
    metaclass.__send__ :undef_method, @meth
    metaclass.__send__ :alias_method, @meth, new_meth_name
    metaclass.__send__ :undef_method, new_meth_name
    @restored = true
    self
  end

  def returns v
    @returns = v
    self
  end

  def times n
    @count = n + 1
    self
  end

  def verify
    @count != 0 or flunk
    self
  end

  def with *a, &b
    @with = b || a
    self
  end

  def yields val
    @yields = val
    self
  end

  private

  def flunk msg = nil
    raise MiniTest::Assertion, msg
  end

  def metaclass
    return @subject if @any_instance
    class << @subject; self; end
  end

  def new_meth_name
    "__miniexpects__#{@meth}"
  end

end

class Object
  def expects name
    MiniTest::Expects.new(self).expects(name)
  end

  def any_instance
    MiniTest::Expects.new(self).any_instance
  end
end

class MiniTest::Unit::TestCase
  include MiniTest::Expects::LifeCycleHooks
end
