require 'rails_helper'

describe StatsController do
  describe '#set_minutes_from_calldate' do
    describe 'when calldate tz is' do
      it 'same as user tz' do
        current_user = User.new
        allow(controller).to receive(:current_user).and_return(current_user)
        calldate = '2012-11-30 15:49:30 +0200'.to_time
        expect(controller.set_minutes_from_calldate(calldate)).to eq(829)
      end

      it 'not same as user tz' do
        current_user = User.new
        allow(controller).to receive(:current_user).and_return(current_user)
        calldate = '2012-11-30 15:49:30 +0400'.to_time
        expect(controller.set_minutes_from_calldate(calldate)).to_not eq(829)
      end
    end
  end
end
