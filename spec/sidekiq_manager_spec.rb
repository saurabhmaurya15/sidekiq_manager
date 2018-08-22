require 'spec_helper'

RSpec.describe SidekiqManager do
  it 'has a version number' do
    expect(SidekiqManager::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
