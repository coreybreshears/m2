require 'spec_helper'
require 'rails_helper'

describe 'tariffs/rate_details.html.erb' do

  before :all do
    assign(:wdfd, true)
    assign(:can_edit, true)
    assign(:rate_details, [])
  end

  before :each do
    @rate = Rate.new
    @destination = Destination.new(prefix: '370')
    @tariff = Tariff.new
    @user_current = User.new(time_zone: 'Vilnius')
    allow(@rate).to receive(:id) { 1 }
    allow(@destination).to receive(:direction) { Direction.new }
    @destination.define_singleton_method(:destination_name) { 'American Samoa' }
    allow(@tariff).to receive(:currency) { 'USD' }

    assign(:rate, @rate)
    assign(:destination, @destination)
    assign(:tariff, @tariff)
  end

  before do
    controller.singleton_class.class_eval do
      def user_tz
        'Vilnius'
      end
      helper_method :user_tz
    end
  end

  it 'should contain rate id as a hidden field tag' do
    render
    expect(rendered).to include("id=\"rateId\"")
  end

  it 'should not show destination if destination is nil' do
    assign(:destination, nil)
    render
    expect(rendered).not_to include("id=\"destination\"")
  end

  it 'should not show destination if destination class is not destination' do
    assign(:destination, 'bad value')
    render
    expect(rendered).not_to include("id=\"destination\"")
  end

  it 'should show destination if prefix is nil and destination is set' do
    allow(@destination).to receive(:prefix).and_return(nil)
    render
    expect(rendered).to include("id=\"destination\"")
  end

  it 'should contain Web Dir as a hidden field tag' do
    stub_const 'Web_Dir', '/billing'
    hidden_input = '<input.*type="hidden".*value="/billing" />'
    render
    expect(rendered).to match(hidden_input)
  end

  it 'should not have destination_name when destination direction do not exist' do
    allow(@destination).to receive(:direction) { nil }
    render
    expect(rendered).to include('370')
  end

  it 'should have prefix and destination when destination direction exist' do
    allow(@destination).to receive(:direction) { Direction.new }
    render
    expect(rendered).to include('American Samoa', '370')
  end

  it 'should have currency text' do
    render
    expect(rendered).to include('Currency:')
  end

  it 'should show USD currency when tariff currency is USD' do
    render
    expect(rendered).to include('USD')
  end

  it 'should show blank currecy if currency is nil' do
    allow(@tariff).to receive(:currency) { nil }
    render
    expect(rendered).to include('id="currency"')
  end

  it 'should not show currency if tariff is nil' do
    assign(:tariff, nil)
    render
    expect(rendered).to include('id="currency"')
  end

  it 'should not show currency if tariff is not a Tariff class object' do
    assign(:tariff, 'bad value')
    render
    expect(rendered).to include('id="currency"')
  end

  it 'should show EUR currency when tariff currency is EUR' do
    allow(@tariff).to receive(:currency) { 'EUR' }
    render
    expect(rendered).to include('EUR')
  end

  it 'should have effective from text' do
    render
    expect(rendered).to include('Effective From:')
  end

  it 'should respond to %Y.%m.%d :formatted_date_in_user_tz method' do
    session[:date_format] = "%Y.%m.%d"
    allow(@rate).to receive(:effective_from) { '2012-12-11 10:13:14'.to_time }
    render
    expect(rendered).to include('2012.12.11')
  end

  it 'should respond to %Y*%m*%d :formatted_date_in_user_tz method' do
    session[:date_format] = "%Y*%m*%d"
    allow(@rate).to receive(:effective_from) { '1812-10-18 09:13:14'.to_time }
    render
    expect(rendered).to include('1812*10*18')
  end

  it 'should show effective_from time' do
    allow(@rate).to receive(:effective_from) { '1812-10-18 09:13:14'.to_time }
    render
    expect(rendered).to include('09:13:14')
  end

  it 'should not show effective_from time, date if rate is nil' do
    assign(:rate, nil)
    render
    expect(rendered).not_to include('id="time"')
    expect(rendered).not_to include('id="date"')
  end

  it 'should not show effective_from time, date if rate is not a rate class object' do
    assign(:rate, 'wrond value')
    render
    expect(rendered).not_to include('id="time"')
    expect(rendered).not_to include('id="date"')
  end
end