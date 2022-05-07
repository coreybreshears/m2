require 'rails_helper'

describe CallLog, type: :model do
  before(:all) do
    @call_log = CallLog.create(uniqueid: '123456789.0', log: "2015-01-01 11:11:11 [DEBUG] line 1\n2015-01-01 12:22:22 [NOTICE] line 2\n2015-01-01 13:33:33 [WARNING] line 3\n")
    @empty_log = CallLog.create(uniqueid: '123456789.1', log: '')
  end

  describe '.find_log' do
    it 'returns object if call log found' do
      expect(CallLog.find_log('123456789.0')).to eq(@call_log)
    end

    it 'returns nil if object not found' do
      expect(CallLog.find_log('123456789.-1')).to be_nil
    end
  end

  describe '#nice_log' do
    it 'returns nicely separated to array of hash log' do
      nice_log = [
          {ct_date: '2015-01-01 11:11:11 ', ct_type: '[DEBUG]', ct_message:' line 1', ct_type_color: 1},
          {ct_date: '2015-01-01 12:22:22 ', ct_type: '[NOTICE]', ct_message: ' line 2', ct_type_color: 0},
          {ct_date: '2015-01-01 13:33:33 ', ct_type: '[WARNING]', ct_message: ' line 3', ct_type_color: 2}
      ]

      expect(@call_log.nice_log).to eq(nice_log)
    end

    it 'returns empty log without crash' do
      expect(@empty_log.nice_log).to eq([])
    end
  end

  after(:all) do
    @call_log.delete
  end
end
