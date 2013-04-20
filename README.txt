= minitest-expects

* https://github.com/bhenderson/minitest-expects

== DESCRIPTION:

MiniTest flavored Mocha. I like Mocha's[http://gofreerange.com/mocha/docs/]
api. I wanted to see if I could take the simplicity in MiniTest::Mock and add
the Mocha api. A lot of the actual mocking code is ripped straight from
MiniTest::Mock. I couldn't figure out a way to just extend it.

== FEATURES/PROBLEMS:

* Very alpha. I just wanted to see if I could do it. Use Mocha.
  That said, the tests pass so any feedback is welcome.
* I wanted to be able to restore a mocked method within a test. see
  restore[rdoc-ref:MiniTest::Expects#restore].
* with[rdoc-ref:MiniTest::Expects#with] does not take any special
  parameter matchers (although you could easily extend it by overriding #==).
  See the docs for details.
* like MiniTest::Mock and unlike Mocha, expects cannot be called for methods
  that don't exist. I try to account for meta methods (ActiveRecord) by
  checking respond_to?() on the object.
* patches welcome!

== SYNOPSIS:

  sub = Subject.new
  sub.expects(:foo).returns(3)
  sub.foo # => 3

  Subject.any_instance.expects(:bar).returns(3)
  sub = Subject.new
  sub.expects(:bar).returns(3)
  sub.bar # => 3

== REQUIREMENTS:

* minitest (3.3.0 afaikt was the first to provide LifecycleHooks)

== INSTALL:

* gem install

== DEVELOPERS:

After checking out the source, run:

  $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the RDoc.

== LICENSE:

(The MIT License)

Copyright (c) 2013 bhenderson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
