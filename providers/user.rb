#
# Cookbook Name:: ipmi
# Provider:: user
#
# Copyright 2012, LivingSocial
# Author: Paul Thomas <paul.thomas@livingsocial.com>
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

require 'english'

PRIVILEGES = [
  'NO ACCESS',
  'CALLBACK',
  'USER',
  'OPERATOR',
  'ADMINISTRATOR'
]
PRIV_MAP = Hash[PRIVILEGES.map.with_index { |v, i| [v, i] }]
FIELDS = [:name, :callin, :link, :ipmi, :priv]

if node[:ipmi][:manufacturer_name] == 'Hewlett-Packard'
  @channel_number = 2
else
  @channel_number = 1
end

def user_table
  cmd = IO.popen("ipmitool -c user list #{@channel_number}")

  users = {}
  cmd.readlines.each do |line|
    tokens = line.chomp.split(',')
    users[tokens[0].to_i] = Hash[(FIELDS.zip(tokens[1..-1]))]
  end
end

def password_match?(id, password)
  `ipmitool user test #{id} 16 #{password}`
  $CHILD_STATUS.success?
end

def whyrun_supported?
  true
end

action :modify do
  current_user = user_table[new_resource.userid]
  execute 'ipmitool set user name' do
    command "ipmitool user set name #{new_resource.userid} #{new_resource.username}"
    only_if { new_resource.username }
    not_if  { current_user && new_resource.username == current_user[:name] }
  end
  execute 'ipmitool set user password' do
    command "ipmitool user set password #{new_resource.userid} #{new_resource.password}"
    only_if { new_resource.password }
    not_if  { password_match?(new_resource.userid, new_resource.password) }
  end
  execute 'ipmitool user priv' do
    command "ipmitool user priv #{new_resource.userid} #{new_resource.level} #{@channel_number}"
    only_if { new_resource.level }
    not_if  { current_user && new_resource.level == PRIV_MAP[current_user[:priv]] }
  end
end

action :enable do
  execute 'ipmitool user enable' do
    command "ipmitool user enable #{new_resource.userid}"
  end
end

action :disable do
  execute 'ipmitool user disable' do
    command "ipmitool user disable #{new_resource.userid}"
  end
end
