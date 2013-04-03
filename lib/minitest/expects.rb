require 'minitest/unit'

# never    => times(0)
# once     => times(1)
# any time => times(-1)
# n times  => times(n)
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
      mocker.verify.restore
    end
  end

  def initialize subject
    @subject = subject

    @any_instance = false
    @count = -1
    @meth = nil
    @returns = nil
    @with = []

    self.class.instances << self
  end

  def any_instance
    @any_instance = true
    self
  end

  def at_least n
    @at_least = n
    self
  end

  def expects name
    @meth = name
    restore

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

    self
  end

  def match? *args
    flunk "called too many times" if @count == 0

    # extra calls aren't recorded because they raise. If they were
    # counted, we would get double errors from after_teardown.
    @count -= 1
    matched = if Proc === @with
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

    flunk msg unless matched

    raise *@raises if @raises
    yield @yields if block_given?
    @returns
  end

  def never
    times 0
  end

  def once
    times 1
  end

  # passed directly to raise()
  # exception = RuntimeError, message = '', backtrace = nil
  def raises *args
    @raises = args
    self
  end

  def restore
    return self if restored?
    # copied from MiniTest::Mock stub()
    metaclass.__send__ :undef_method, @meth
    metaclass.__send__ :alias_method, @meth, new_meth_name
    metaclass.__send__ :undef_method, new_meth_name
    self
  end

  def returns v
    @returns = v
    self
  end

  def times n
    @count = n
    self
  end

  def verify bt = caller
    @count <= 0 or flunk "#{@subject}.#{@meth} expected. not called", bt
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

  def flunk msg = nil, bt = nil
    raise MiniTest::Assertion, msg, bt
  end

  def metaclass
    return @subject if @any_instance
    class << @subject; self; end
  end

  def new_meth_name
    :"__miniexpects__#{@meth}"
  end

  def restored?
    methods = @any_instance ?
                @subject.instance_methods :
                @subject.methods

    !methods.include? new_meth_name
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
