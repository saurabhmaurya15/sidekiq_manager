require 'spec_helper'

RSpec.describe SidekiqManager do
  it 'has a version number' do
    expect(SidekiqManager::VERSION).not_to be nil
  end
end
