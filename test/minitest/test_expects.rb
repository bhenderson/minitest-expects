require 'minitest/autorun'

require 'minitest/expects'

class TestMiniTest; end
class TestMiniTest::TestExpects < MiniTest::Unit::TestCase
  class Subject
    def self.foo() 'class method' end
    attr_accessor :count
    def initialize() @count = 0 end
    def foo() @count += 1 end
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
  end

  def test_expects
    @sub.
      expects(:foo)

    assert_equal 0, @sub.count, 'expects shouldnt call the method'

    @sub.foo()

    assert_equal 0, @sub.count, 'expects should replace the method'
  end

  def test_returns
    @sub.
      expects(:foo).
      returns(:bar)

    assert_equal :bar, @sub.foo
  end

  def test_with
    @sub.
      expects(:foo).
      with(1, nil, 2)

    @sub.foo(1, nil, 2)

    util_raises "wrong arguments [1, 2]\nexpected [1, nil, 2]" do
      @sub.foo(1, 2)
    end
    util_raises do
      @sub.foo(1)
    end
    util_raises do
      @sub.foo(1,nil,2,3)
    end
  end

  def test_with_class
    @sub.
      expects(:foo).
      with(@class)

    @sub.foo(@sub)
    @sub.foo(@class)

    util_raises do
      @sub.foo(2)
    end
  end

  def test_with_any_parameter
    @sub.
      expects(:foo).
      with(Object)

    @sub.foo(@sub)
  end

  def test_with_block
    @sub.
      expects(:foo).
      with{|v| v == 42}

    @sub.foo(42)

    m = @sub.
      expects(:foo).
      with{|v| v == 41}

    util_raises "arguments block returned false" do
      @sub.foo(42)
    end
  end

  def test_class_expects
    m = @class.
      expects(:foo)

    refute @class.foo
    m.restore

    assert_equal 'class method', @class.foo
  end

  def test_verify
    m = @sub.
      expects(:foo)

    util_raises do
      m.verify
    end

    @sub.foo
    assert m.verify
  end

  def test_times
    m = @sub.
      expects(:foo)

    m.times(0)

    util_raises 'called too many times' do
      @sub.foo
    end

    m.times(2)

    @sub.foo
    @sub.foo

    util_raises do
      @sub.foo
    end
  end

  def test_yields
    def @sub.bar() yield 3 end

    @sub.
      expects(:bar).
      yields(4)

    val = nil
    @sub.bar do |v| val = v end

    assert_equal 4, val
  end

  def test_any_instance
    Subject.
      any_instance.
      expects(:foo).
      returns('any')

    assert_equal 'any', @sub.foo
  end

  def test_returns_self
    m = @sub.expects(:foo)
    assert_kind_of MiniTest::Expects, m
    assert_same m, m.restore
    assert_same m, m.returns(1)
    assert_same m, m.times(1)
    assert_same m, m.with(1)
    assert_same m, m.yields(1)
  end

  def test_expects_non_existent_method
    assert_raises NameError do
      @sub.expects(:bar)
    end
  end

  def test_method_missing_methods
    m = @sub.
      expects(:meta_meth).
      returns('new')

    assert_equal 'new', @sub.meta_meth

    m.restore

    assert_equal 'meta method', @sub.meta_meth
  end

  def test_restore
    @sub.expects(:foo)
    m = @sub.expects(:foo)
    m.restore
    m.restore
    assert_equal 1, @sub.foo
  end

  def util_raises msg = nil
    e = assert_raises MiniTest::Assertion do
      yield
    end
    assert_equal msg, e.message if msg
  end

end
