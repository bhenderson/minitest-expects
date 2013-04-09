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
    @mock = @sub.expects(:foo)
  end

  def test_expects
    assert_equal 0, @sub.count, 'expects shouldnt call the method'

    @sub.foo()

    assert_equal 0, @sub.count, 'expects should replace the method'
  end

  def test_returns
    @mock.returns(:bar)

    assert_equal :bar, @sub.foo
  end

  def test_with
    @mock.
      with(1).
      times(-1)

    @sub.foo 1

    util_raises "mocked method :foo expects 1 arguments, got 2" do
      @sub.foo 1, 2
    end
    util_raises "mocked method :foo called with unexpected arguments [2]" do
      @sub.foo 2
    end
    util_raises "mocked method :foo expects 1 arguments, got 0" do
      @sub.foo
    end
  end

  def test_with_class
    @mock.
      with(@class).
      times(-1)

    @sub.foo(@sub)
    @sub.foo(@class)

    util_raises do
      @sub.foo(2)
    end
  end

  def test_with_any_parameter
    @mock.with(Object)

    @sub.foo(@sub)
  end

  def test_with_block
    @mock.with{|v| v == 42}

    @sub.foo(42)

    @mock.with{|v| v == 41}.once

    util_raises "mocked method :foo argument block returned false" do
      @sub.foo(42)
    end

    @mock.with{|v1,v2| v1 == :bugs and v2 == :bunny }.once
    @sub.foo(:bugs, :bunny)
  end

  def test_restore
    @mock.restore
    @mock.restore
    assert_equal 1, @sub.foo
    assert @mock.verify
  end

  def test_class_expects
    @mock.restore

    m = @class.
      expects(:foo)

    refute @class.foo
    m.restore

    assert_equal 'class method', @class.foo
  end

  def test_default_times_once
    @sub.foo
    util_raises do
      @sub.foo
    end
    assert @mock.verify
  end

  def test_times_never
    @mock.times(0)

    util_raises 'called too many times' do
      @sub.foo
    end

    assert @mock.verify
  end

  def test_times_once
    @mock.times(1)

    @sub.foo
    util_raises do
      @sub.foo
    end

    assert @mock.verify
  end

  def test_times_twice
    @mock.times(2)

    @sub.foo
    @sub.foo
    util_raises do
      @sub.foo
    end

    assert @mock.verify
  end

  def test_yields
    def @sub.bar() yield 3 end

    @sub.
      expects(:bar).
      yields(4)

    val = nil
    @sub.bar do |v| val = v end

    assert_equal 4, val

    @mock.restore
  end

  def test_yields_failure
    def @sub.bar() yield 3 end
    m = @sub.
      expects(:bar).
      yields(4)

    util_raises 'mocked method :bar expected to yield, no block given' do
      @sub.bar
    end

    util_raises do
      m.verify
    end

    @mock.restore
    m.restore
  end

  def test_yields_returns
    @mock.restore

    def @sub.bar() yield 3 end
    @mock = @sub.
      expects(:bar).
      yields(4)

    def self.return_bar
      @sub.bar do return end
    end
    return_bar

    assert @mock.verify
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

    @mock.restore
  end

  def test_any_instance
    @mock.restore

    @mock = @class.
              any_instance.
              expects(:third).
              returns('tres')

    assert_equal 'tres', @sub.third

    @mock.restore

    assert_equal 3, @sub.third
  end

  def test_returns_self
    assert_kind_of MiniTest::Expects, @mock
    assert_same @mock, @mock.raises
    assert_same @mock, @mock.restore
    assert_same @mock, @mock.restore
    assert_same @mock, @mock.returns
    assert_same @mock, @mock.times(0)
    assert_same @mock, @mock.with
    assert_same @mock, @mock.yields
  end

  def test_expects_non_existent_method
    assert_raises NameError do
      @sub.expects(:bar)
    end

    @mock.restore
  end

  def test_method_missing_methods
    m = @sub.
      expects(:meta_meth).
      returns('new')

    assert_equal 'new', @sub.meta_meth

    m.restore

    assert_equal 'meta method', @sub.meta_meth

    @mock.restore
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
    @mock.raises

    assert_raises RuntimeError do
      @sub.foo
    end
  end

  def test_raises_specific_error
    err = Class.new ::Exception
    @mock.raises(err)

    assert_raises err do
      @sub.foo
    end
  end

  def test_raises_message
    @mock.raises('error')

    e = assert_raises RuntimeError do
      @sub.foo
    end
    assert_equal 'error', e.message
  end

  def test_raises_error_and_message_and_backtrace
    err = Class.new ::Exception
    @mock.raises(err, 'error', ['bt'])

    e = assert_raises err do
      @sub.foo
    end
    assert_equal 'error', e.message
    assert_equal ['bt'], e.backtrace
  end

  def test_override_count
    @mock.times 1

    m = @sub.
      expects(:foo).
      never

    assert_same @mock, m
  end

  def test_called_wrong_params
    @mock.with(1).once

    util_raises do
      @sub.foo(2)
    end

    util_raises do
      @mock.verify
    end

    @sub.foo(1) # verify
  end

  def test_mock_method_name_string
    m = @sub.expects('foo')

    assert_same m, @mock

    @mock.restore
    m.restore
  end

  def test_verify_message
    @mock.once

    util_raises "mocked method :foo not called 1 times" do
      @mock.verify
    end

    @sub.foo # verify
  end

  def util_raises msg = nil
    e = assert_raises MiniTest::Assertion do
      yield
    end
    assert_equal msg, e.message if msg
  end

end
