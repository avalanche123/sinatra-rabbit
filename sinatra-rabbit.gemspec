#
# Copyright (C) 2010  Red Hat, Inc.
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

require 'rake'

Gem::Specification.new do |s|
  s.author = 'Red Hat, Inc.'
  s.homepage = "http://incubator.apache.org/deltacloud"
  s.email = 'deltacloud-dev@incubator.apache.org'
  s.name = 'sinatra-rabbit'

  s.description = <<-EOF
    Rabbit is a Sinatra extension which can help you writing
    a simple REST API using easy to undestand DSL.
  EOF

  s.version = '0.0.1'
  s.date = Time.now
  s.summary = %q{Sinatra REST API DSL}
  s.files = FileList[
    'lib/sinatra/*.rb',
    'lib/sinatra/rabbit/*.rb',
    'sinatra-rabbit.gemspec',
  ].to_a

  s.extra_rdoc_files = Dir["COPYING"]
  s.required_ruby_version = '>= 1.8.1'

  s.add_runtime_dependency 'sinatra', '>= 0.9.4'
  s.add_runtime_dependency 'rack-accept', '>= 0.4.3'

  s.add_dependency('haml', '>= 2.2.17')

end
