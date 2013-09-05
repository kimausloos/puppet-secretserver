#!/usr/bin/env rspec

require 'spec_helper'

describe 'secretserver' do
  it { should contain_class 'secretserver' }
end
