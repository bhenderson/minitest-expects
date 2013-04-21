# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :git
Hoe.plugin :isolate
Hoe.plugin :minitest
Hoe.plugin :version

Hoe.spec 'minitest-expects' do
  developer('Brian Henderson', 'henderson.bj@gmail.com')

  self.testlib = :none

  extra_deps << ['minitest', ['>= 3.3.0', '< 5.0']]
end

# vim: syntax=ruby
