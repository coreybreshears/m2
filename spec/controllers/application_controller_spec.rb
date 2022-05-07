require 'spec_helper'
require 'rails_helper'
require 'rspec/mocks'
require 'factory_girl'

describe ApplicationController do

  describe '#to_default_date' do

    it 'default format' do
      expect(controller.to_default_date('2012-05-14 12:35')).to eq('2012-05-14 12:35:00')
    end

    it 'default format no date' do
      expect(controller.to_default_date('12:35')).to eq(false)
    end

    it 'default format time' do
      expect(controller.to_default_date('12:35')).to eq(false)
    end

    it 'default format no date time' do
      expect(controller.to_default_date('')).to eq(false)
    end


    it 'custom format wrong format' do
      session[:date_format] = "%m/%d/%Y"
      expect(controller.to_default_date('2012-05-14 12:35')).to eq(false)
    end


    it 'custom format' do
      session[:date_format] = "%m/%d/%Y"
      expect(controller.to_default_date('05/14/2012 12:35')).to eq('2012-05-14 12:35:00')
    end

    it 'custom format nil' do
      session[:date_format] = "%m/%d/%Y"
      expect(controller.to_default_date(nil)).to eq(false)
    end
  end


end