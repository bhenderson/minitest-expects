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
      MiniTest::Expects.teardown
    end
  end

  def self.instances
    @instances ||= Hash.new
  end

  def self.teardown
    @instances.values.each do |expecter|
      expecter.verify.restore
    end
  end

  def initialize subject, any_instance = false
    @subject = subject

    @any_instance = !!any_instance
    @count = 1
    @meth = nil
    @returns = nil
    @with = []
  end

  def expects name
    name = name.intern
    if expecter = self.class.instances[[@subject,name]]
      return expecter
    end

    @meth = name

    # copied from MiniTest::Mock stub()
    # TODO make this work for any_instance
    if @subject.respond_to? name and
      not @subject.methods.map(&:to_s).include? name.to_s then
      metaclass.send :define_method, name do |*args|
        super(*args)
      end
    end

    metaclass.__send__ :alias_method, new_meth_name, @meth

    expecter = self
    metaclass.__send__ :define_method, name do |*args, &block|
      expecter.match?(*args, &block)
    end

    self.class.instances[[@subject,name]] = self

    self
  end

  def match? *args
    # copied some error messages and logic from MiniTest::Mock.

    flunk "called too many times" if @count == 0

    if Proc === @with
      unless @with.call(*args)
        flunk "mocked method %p argument block returned false" %
          [@meth]
      end
    else
      if @with.size != args.size
        flunk "mocked method %p expects %d arguments, got %d" %
          [@meth, @with.size, args.size]
      end

      fully_matched = @with.zip(args).all? { |val1, val2|
        val1 == val2 or val1 === val2
      }

      unless fully_matched
        flunk "mocked method %p called with unexpected arguments %p" %
          [@meth, args]
      end
    end

    # TODO check arity?
    if @yields
      unless block_given?
        flunk "mocked method %p expected to yield, no block given" %
          [@meth]
      end
    end

    # extra calls aren't recorded because they raise. If they were
    # counted, we would get double errors from after_teardown.
    @count -= 1

    # must be after count
    yield *@yields if block_given?

    raise *@raises if @raises

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

    # satisfy verify
    @count = -1
    self
  end

  def returns val = nil
    @returns = val
    self
  end

  def times num
    @count = num
    self
  end

  def verify
    if @count > 0
      flunk "mocked method %p not called %d times" %
        [@meth, @count]
    end
    self
  end

  def with *args, &block
    @with = block || args
    self
  end

  def yields *args
    @yields = args
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
    MiniTest::Expects.new(self, true)
  end
end

class MiniTest::Unit::TestCase
  include MiniTest::Expects::LifeCycleHooks
end
