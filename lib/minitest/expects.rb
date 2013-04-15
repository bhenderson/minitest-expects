require 'minitest/unit'
require 'minitest/mock'

##
# Mocking framework based off of MiniTest::Mock, but with the api of
# Mocha
#
#   class Greeter
#     def hi
#       'hello world'
#     end
#   end
#
#   gtr = Greeter.new
#   expecter = gtr.expects(:hi).returns 'yo!'
#
#   gtr.hi # => 'yo!'
#   expecter.verify # => true
#   expecter.restore
#
#   gtr.hi # => 'hello world'

class MiniTest::Expects
  VERSION = '0.1.0'

  def self.expects subject, name # :nodoc:
    # save an instance creation at the cost of duplicating #instance_key
    # logic.
    instances[[subject, name.intern]] || new(subject).expects(name)
  end

  def self.instances # :nodoc:
    @instances ||= Hash.new
  end

  def self.teardown # :nodoc:
    @instances.values.each do |expecter|
      expecter.verify.restore
    end
  end

  def initialize subject, any_instance = false # :nodoc:
    @subject = subject

    @any_instance = !!any_instance
    @count = 1
    @meth = nil
    @returns = nil
    @with = [] # default no parameters
  end

  def initialize_dup other # :nodoc:
    initialize other.subject, other.any_instance
  end

  ##
  # Allow any number of times.

  def any_time
    times -1
  end

  ##
  # Main entry method. This method is invoked when Object#expects is
  # called. It returns the same expecter if +name+ and subject is the
  # same.
  #
  #   exp1 = gtr.expects(:hi)
  #   exp2 = gtr.expects(:hi)
  #
  #   exp1.equal exp2
  #
  # If Class#any_instance is used, it returns a new expecter for each
  # unique +name+
  #
  # The default behavior is that it is expected to be called exactly one
  # time, with no arguments and returns nil. All of these behaviors are
  # of course configurable using the api methods.

  def expects name
    # any_instance
    return dup.expects(name) if @meth

    @meth = name.intern

    if expecter = self.class.instances[instance_key]
      return expecter
    end

    # woh! is this hacky? Call allocate to get around not knowing how to call
    # new().
    sub = @any_instance ? @subject.allocate : @subject

    # handle meta methods.
    # copied from MiniTest::Mock stub()
    if sub.respond_to? name and
      not sub.methods.map(&:to_s).include? name.to_s then
      subject_class.__send__ :define_method, name do |*args|
        super(*args)
      end
    end

    subject_class.__send__ :alias_method, new_meth_name, @meth

    expecter = self
    subject_class.__send__ :define_method, name do |*args, &block|
      expecter.match?(*args, &block)
    end

    self.class.instances[instance_key] = self

    self
  end

  def match? *args # :nodoc:
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

  ##
  # Never called.
  #
  # see #times

  def never
    times 0
  end

  ##
  # Called exactly one time.
  #
  # see #times

  def once
    times 1
  end

  ##
  # Set mocked method to raise when called.
  #
  # Arguments are exactly like raise()
  # :args: RuntimeError, message = '', backtrace = nil

  def raises *args
    @raises = args
    self
  end

  ##
  # Restore the mocked method to original.

  def restore
    return self if restored?

    # copied from MiniTest::Mock stub()
    subject_class.__send__ :undef_method, @meth
    subject_class.__send__ :alias_method, @meth, new_meth_name
    subject_class.__send__ :undef_method, new_meth_name

    # remove self
    self.class.instances.delete instance_key

    # satisfy verify
    @count = -1

    self
  end

  ##
  # Set what the mocked method returns.

  def returns val = nil
    @returns = val
    self
  end

  ##
  # Set how many times the mocked method can be called.
  #
  # 0  - exactly 0 times.
  # +n - exactly +num+ times
  # -n - any number of times.

  def times num
    @count = num
    self
  end

  ##
  # Verify that the mocked method was called appropriately.
  #
  # Raises if false.

  def verify
    if @count > 0
      flunk "mocked method %p not called %d times" %
        [@meth, @count]
    end
    self
  end

  ##
  # Set the expected arguments of the mocked method.
  #
  # Arguments are matched against #== then #=== to allow case matching.
  #
  # Raises when mocked method arguments don't match.

  def with *args, &block
    @with = block || args
    self
  end

  ##
  # Set the value that the mocked method yields when called.
  #
  # Raises if mocked method not called with a block.

  def yields *args
    @yields = args
    self
  end

  protected

  attr_reader :subject, :any_instance

  private

  def flunk msg = nil
    raise MockExpectationError, msg
  end

  def instance_key
    [@subject, @meth]
  end

  def subject_class
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

# :stopdoc:

class Object
  def expects name
    MiniTest::Expects.expects(self, name)
  end
end

class Class
  def any_instance
    MiniTest::Expects.new(self, true)
  end
end

module MiniTest::Expects::LifeCycleHooks
  def before_setup
    MiniTest::Expects.instances.clear
    super
  end

  def after_teardown
    super
    MiniTest::Expects.teardown
  end
end

class MiniTest::Unit::TestCase
  include MiniTest::Expects::LifeCycleHooks
end
