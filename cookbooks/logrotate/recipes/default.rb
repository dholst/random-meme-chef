#
# Cookbook Name:: logrotate
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package "logrotate" do
  action :upgrade
end

logrotate_app "www" do
  path "/var/log/www/*.log"
  frequency "daily"
  rotate 30
  create "644 root adm"
end

logrotate_app "chef" do
  path "/var/log/chef/*.log"
  frequency "daily"
  rotate 30
  create "644 root adm"
end