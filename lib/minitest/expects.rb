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

  def self.expects subject, name
    instances[[subject,name]] ||= new(subject).expects(name)
  end

  def self.instances
    @instances ||= {}
  end

  def self.teardown
    @instances.values.each do |mocker|
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
  end

  def any_instance
    @any_instance = true
    self
  end

  def expects name
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

    self
  end

  def match? *args
    flunk "called too many times" if @count == 0

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

    # extra calls aren't recorded because they raise. If they were
    # counted, we would get double errors from after_teardown.
    @count -= 1

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

  def returns val = nil
    @returns = val
    self
  end

  def times num
    @count = num
    self
  end

  def verify
    msg = "#{@subject}.#{@meth} not called sufficient number of times."
    @count <= 0 or flunk msg
    self
  end

  def with *args, &block
    @with = block || args
    self
  end

  def yields val = nil
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
    MiniTest::Expects.expects(self, name)
  end

  def any_instance
    MiniTest::Expects.new(self).any_instance
  end
end

class MiniTest::Unit::TestCase
  include MiniTest::Expects::LifeCycleHooks
end
