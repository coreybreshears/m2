require 'spec_helper'
require 'rails_helper'
require 'rspec/mocks'
require 'factory_girl'

describe TariffsController do

  describe '#update_effective_from_ajax' do

    describe 'admin' do

      before :each do
        @current_user = FactoryGirl.create(:user, usertype: 'admin')
        @tariff = @current_user.owned_tariffs.first
        @rate = @tariff.rates.first
        allow(controller).to receive(:corrected_user_id).and_return(@current_user.id)
      end

      describe 'should render user to login page if user' do
        it 'is not logged in' do
          put :update_effective_from_ajax, {id: @rate, date: '1998-12-14', time: '10:12:11'}, {usertype: nil, user_id: nil}
          expect(controller).to redirect_to controller: :callc, action: :login
        end

        it 'usertype is unknown' do
          put :update_effective_from_ajax, {id: @rate.id, date: '1998-12-14', time: '10:12:11'}, {usertype: 'bad usertype'}
          expect(controller).to redirect_to controller: :callc, action: :login
        end

      end

      it 'should render user to root if user usertype is user' do
        put :update_effective_from_ajax, {id: @rate.id, date: '1998-12-14', time: '10:12:11'}, {usertype: 'user', user_id: @current_user.id}
        expect(controller).to redirect_to :root
      end

      describe 'should not update rate.effective_from' do


        it 'if params[:id] is blank' do
          put :update_effective_from_ajax, {id: nil, date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
          expect(response.body).to include('error', 'Rate Was Not Found')
        end

        it 'if params[:id] is incorrect' do
          put :update_effective_from_ajax, {id: 'zzaas', date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
          expect(response.body).to include('error', 'Rate Was Not Found')
        end

        it 'if rate tariff do not belong to current user' do
          @tariff.update_attributes!(owner_id: 20000)
          put :update_effective_from_ajax, {id: @rate.id, date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
          expect(response.body).to include('2012-12-14', '08:15:00')
        end

        it 'if date format is invalid' do
          put :update_effective_from_ajax, {id: @rate, date: '1998 babas 12 babas 14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
          expect(response.body).to include('2012-12-14', '08:15:00')
        end

        it 'if date is blank' do
          put :update_effective_from_ajax, {id: @rate, date: '', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
          expect(response.body).to include('2012-12-14', '08:15:00')
        end

      end

      it 'should update rate.effective_from if all variables are correct' do
        put :update_effective_from_ajax, {id: @rate, date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
        @rate.reload
        expect(@rate.effective_from.to_s).to include('1998-12-14 10:12:11')
      end

    end

  end

  describe '#update_effective_from_ajax' do

    describe 'manager' do

      it 'should not update rate.effective_from if there are no billing > tariffs permission' do
        @manager_group = FactoryGirl.create(:manager_group)
        @current_user = @manager_group.managers.first
        @tariff = @current_user.owned_tariffs.first
        @rate = @tariff.rates.first
        allow(controller).to receive(:corrected_user_id).and_return(@current_user.id)

        put :update_effective_from_ajax, {id: @rate, date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
        @rate.reload
        expect(controller).to redirect_to :root
      end

      it 'should update rate.effective_from if all variables are correct' do
        @manager_group = FactoryGirl.create(:manager_group_with_tariffs_right)
        @current_user = @manager_group.managers.first
        @tariff = @current_user.owned_tariffs.first
        @rate = @tariff.rates.first
        allow(controller).to receive(:corrected_user_id).and_return(@current_user.id)

        put :update_effective_from_ajax, {id: @rate, date: '1998-12-14', time: '10:12:11'}, {usertype: @current_user.usertype, user_id: @current_user.id}
        @rate.reload
        expect(@rate.effective_from.to_s).to include('1998-12-14 10:12:11')
      end

    end

  end

end