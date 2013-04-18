require 'minitest/autorun'

require 'minitest/expects'

class TestMiniTest; end
class TestMiniTest::TestExpects < MiniTest::Unit::TestCase
  class Subject
    def self.foo() 'class method' end
    attr_accessor :count
    def initialize() @count = 0 end
    def foo() @count += 1 end
    def third() 3 end
    def method_missing(name)
      if name == :meta_meth
        class << self
          define_method :meta_meth do
            'meta method'
          end
        end
        send name
      else
        super
      end
    end
    def respond_to?(name)
      name == :meta_meth or super
    end
  end

  def setup
    @class = Subject
    @sub = @class.new
    @exp = @sub.expects(:foo)
  end

  def test_expects
    assert_equal 0, @sub.count, 'expects shouldnt call the method'

    @sub.foo()

    assert_equal 0, @sub.count, 'expects should replace the method'
  end

  def test_returns
    @exp.returns(:bar)

    assert_equal :bar, @sub.foo
  end

  def test_with
    @exp.
      with(1).
      times(-1)

    @sub.foo 1

    msg = "mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX "\
          "@count=0>.foo expects 1 arguments, got 2"
    util_raises msg do
      @sub.foo 1, 2
    end
    msg = "mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX "\
          "@count=0>.foo called with unexpected arguments [2]"
    util_raises msg do
      @sub.foo 2
    end
    msg = "mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX "\
          "@count=0>.foo expects 1 arguments, got 0"
    util_raises msg do
      @sub.foo
    end
  end

  def test_with_class
    @exp.
      with(@class).
      times(-1)

    @sub.foo(@sub)
    @sub.foo(@class)

    util_raises do
      @sub.foo(2)
    end
  end

  def test_with_any_parameter
    @exp.with(Object)

    @sub.foo(@sub)
  end

  def test_with_block
    @exp.with{|v| v == 42}

    @sub.foo(42)

    @exp.with{|v| v == 41}.once

    msg = "mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX "\
          "@count=0>.foo argument block returned false"
    util_raises msg do
      @sub.foo(42)
    end

    @exp.with{|v1,v2| v1 == :bugs and v2 == :bunny }.once
    @sub.foo(:bugs, :bunny)
  end

  def test_restore
    @exp.restore
    @exp.restore
    assert_equal 1, @sub.foo
    assert @exp.verify
  end

  def test_class_expects
    @exp.restore

    exp = @class.
      expects(:foo)

    refute @class.foo
    exp.restore

    assert_equal 'class method', @class.foo
  end

  def test_default_times_once
    @sub.foo
    util_raises do
      @sub.foo
    end
    assert @exp.verify
  end

  def test_times_never
    @exp.times(0)

    msg = 'mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX '\
          '@count=0>.foo called too many times'
    util_raises msg do
      @sub.foo
    end

    assert @exp.verify
  end

  def test_times_once
    @exp.times(1)

    @sub.foo
    util_raises do
      @sub.foo
    end

    assert @exp.verify
  end

  def test_times_twice
    @exp.times(2)

    @sub.foo
    @sub.foo
    util_raises do
      @sub.foo
    end

    assert @exp.verify
  end

  def test_yields
    def @sub.bar() yield 3 end

    @sub.
      expects(:bar).
      yields(4)

    val = nil
    @sub.bar do |v| val = v end

    assert_equal 4, val

    @exp.restore
  end

  def test_yields_failure
    def @sub.bar() yield 3 end
    exp = @sub.
      expects(:bar).
      yields(4)

    msg = 'mocked method #<TestMiniTest::TestExpects::Subject:0xXXXXXX '\
          '@count=0>.bar expected to yield, no block given'
    util_raises msg do
      @sub.bar
    end

    util_raises do
      exp.verify
    end

    @exp.restore
    exp.restore
  end

  def test_yields_returns
    @exp.restore

    def @sub.bar() yield 3 end
    @exp = @sub.
      expects(:bar).
      yields(4)

    def self.return_bar
      @sub.bar do return end
    end
    return_bar

    assert @exp.verify
  end

  def test_yields_multiple_params
    def @sub.bar() yield 1,2 end

    val = nil
    @sub.bar do |*a| val = a end
    assert_equal [1,2], val

    @sub.
      expects(:bar).
      yields(3,4)

    @sub.bar do |*a| val = a end
    assert_equal [3,4], val

    @exp.restore
  end

  def test_any_instance
    @exp.restore

    @exp = @class.
              any_instance.
              expects(:third).
              returns('tres')

    assert_equal 'tres', @sub.third

    @exp.restore

    assert_equal 3, @sub.third
  end

  def test_returns_self
    assert_kind_of MiniTest::Expects, @exp
    assert_same @exp, @exp.raises
    assert_same @exp, @exp.restore
    assert_same @exp, @exp.restore
    assert_same @exp, @exp.returns
    assert_same @exp, @exp.times(0)
    assert_same @exp, @exp.with
    assert_same @exp, @exp.yields
  end

  def test_expects_non_existent_method
    assert_raises NameError do
      @sub.expects(:bar)
    end

    @exp.restore
  end

  def test_method_missing_methods
    exp = @sub.
      expects(:meta_meth).
      returns('new')

    assert_equal 'new', @sub.meta_meth

    exp.restore

    assert_equal 'meta method', @sub.meta_meth

    @exp.restore
  end

  def test_expects_multiple_methods
    def @sub.bar() 3 end

    m1 = @sub.expects(:foo)
    m2 = @sub.expects(:bar)

    @sub.foo
    @sub.bar

    m1.restore
    m2.restore

    assert_equal 1, @sub.foo
    assert_equal 3, @sub.bar
  end

  def test_raises_default_error
    @exp.raises

    assert_raises RuntimeError do
      @sub.foo
    end
  end

  def test_raises_specific_error
    err = Class.new ::Exception
    @exp.raises(err)

    assert_raises err do
      @sub.foo
    end
  end

  def test_raises_message
    @exp.raises('error')

    e = assert_raises RuntimeError do
      @sub.foo
    end
    assert_equal 'error', e.message
  end

  def test_raises_error_and_message_and_backtrace
    err = Class.new ::Exception
    @exp.raises(err, 'error', ['bt'])

    e = assert_raises err do
      @sub.foo
    end
    assert_equal 'error', e.message
    assert_equal ['bt'], e.backtrace
  end

  def test_override_count
    @exp.times 1

    exp = @sub.
      expects(:foo).
      never

    assert_same @exp, exp
  end

  def test_called_wrong_params
    @exp.with(1).once

    util_raises do
      @sub.foo(2)
    end

    util_raises do
      @exp.verify
    end

    @sub.foo(1) # verify
  end

  def test_mock_method_name_string
    exp = @sub.expects('foo')

    assert_same exp, @exp

    @exp.restore
    exp.restore
  end

  def test_verify_message
    @exp.once

    util_raises "mocked method :foo not called 1 times" do
      @exp.verify
    end

    @sub.foo # verify
  end

  def test_any_instance_reuse
    @exp.restore

    klass = Class.new do
      def foo() :foo end
      def bar() :bar end
    end

    m1 = klass.
      any_instance.
      expects(:foo)
    m2 = klass.
      any_instance.
      expects(:foo)

    assert_same m1, m2

    m1.restore
  end

  def test_any_time
    @exp.any_time
    assert @exp.verify

    @sub.foo
    assert @exp.verify

    @sub.foo
    assert @exp.verify
  end

  def test_default_no_params
    util_raises do
      @sub.foo 1
    end

    @sub.foo # verify
  end

  def test_with_any_parameters
    @exp.with{ true }

    @sub.foo 1,2,3

    pass
  end

  def test_with_no_parameters
    @exp.with{ true }
    @exp.with # override

    util_raises do
      @sub.foo 1
    end

    @sub.foo
    pass
  end

  def test_any_instance_meta_method
    @exp.restore

    @class.
      any_instance.
      expects(:meta_meth).
      returns('mocked!')

    assert_equal 'mocked!', @sub.meta_meth
  end

  def test_any_instance_only_on_class
    @exp.restore

    assert_raises NoMethodError do
      @sub.any_instance
    end
  end

  def test_duplicate_expects_any_instance
    @exp.restore

    exp = @class.any_instance.expects(:foo).returns :any_instance

    @exp = @sub.expects(:foo).returns :instance

    assert_equal :instance, @sub.foo
    assert_equal :any_instance, @class.new.foo

    @exp.restore
    exp.restore

    assert_equal 1, @sub.foo
    assert_equal 1, @class.new.foo
  end

  def test_double_any_instance
    @exp.restore

    @class = Class.new do
      def foo() :foo end
      def bar() :bar end
    end

    @class.any_instance.expects(:foo).returns('foo')
    @class.any_instance.expects(:bar).returns('bar')

    @sub = @class.new

    assert_equal 'foo', @sub.foo
    assert_equal 'bar', @sub.bar
  end

  def test_any_instance_double_expects
    @exp.restore

    @class = Class.new do
      def foo() :foo end
      def bar() :bar end
    end

    @exp = @class.any_instance

    @exp.expects(:foo).returns 'foo'
    new_exp = @exp.expects(:bar).returns 'bar'

    refute_same @exp, new_exp

    @sub = @class.new

    assert_equal 'foo', @sub.foo
    assert_equal 'bar', @sub.bar
  end

  def test_class_level_lookup
    MiniTest::Expects.instances[[@sub, :foo]] = :foo

    assert_equal :foo, @sub.expects(:foo)

    MiniTest::Expects.instances.delete [@sub, :foo]
  end

  def test_module_methods
    @exp.restore

    Kernel.any_instance.expects(:sleep).with(10)

    t0 = Time.now

    assert_nil sleep 10

    assert_in_delta Time.now, t0, 1
  end

  def test_only_verify_if_passed_eh
    def self.before_teardown
      @passed = false
      super
    end
    assert @exp # make sure we still have this.
  end

  def test_restore_always
    @class.expects(:foo).returns 'mocked'
    MiniTest::Expects.teardown false

    assert_equal 'class method', @class.foo
  end

  def test_returns_original
    @exp.returns_original

    assert_equal 1, @sub.foo
  end

  # TODO better error messaging

  def util_raises msg = nil
    e = assert_raises MockExpectationError do
      yield
    end
    assert_equal mu_pp_for_diff(msg), mu_pp_for_diff(e.message) if msg
  end

end
