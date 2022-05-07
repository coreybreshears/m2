require 'spec_helper'
require 'rails_helper'

describe 'tariffs/_ratedetail_edit_header' do


  before(:all) do
    @destination = Destination.first
    @destination = Destination.linked_with_rate(@destination.id).first
    @tariff = Tariff.create
    @rate = Rate.create
  end

  before(:each) do
    @tariff.currency = "USD"
    assign(:tariff, @tariff)
    @rate.effective_from = "2010-08-08"
    assign(:rate, @rate)
    @destination.destination_name = "Albania"
    assign(:destination, @destination)
  end

  describe "render currency when" do
    it "changes" do
      @tariff.currency = "EUR"
      assign(:tariff, @tariff)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("EUR")
    end

    it "nil" do
      @tariff.currency = nil
      assign(:tariff, @tariff)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("2010-08-08")
    end
  end

  describe "render effective_from when" do
    it "changes" do
      @rate.effective_from = "2015-05-05"
      assign(:rate, @rate)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("2015-05-05")
    end

    it "nil" do
      @rate.effective_from = nil
      assign(:rate, @rate)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("USD")
    end
  end

  describe "render destination_name when" do
    it "changes" do
    	@destination.destination_name = "babas"
      assign(:destination, @destination)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("babas")
    end

    it "nil" do
      @destination.destination_name = nil
      assign(:destination, @destination)
      render partial: "tariffs/ratedetail_edit_header.html.erb", locals: { destination: @destination, tariff: @tariff, rate: @rate }
      expect(rendered).to match("NAME ERROR")
    end
  end
end