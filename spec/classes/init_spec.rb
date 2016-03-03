require 'spec_helper'
describe 'cftotalcontrol' do

  context 'with defaults for all parameters' do
    it { should contain_class('cftotalcontrol') }
  end
end
