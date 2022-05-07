require 'spec_helper'
require 'rails_helper'
require 'rspec/mocks'
require 'factory_girl'

describe Tariff do
  describe '.generate_sql_for_update' do
    it 'Egypt rate with destination_id 144' do
      update = {
        "FRA" => {"FIX" => [44, 70], :destination_id => 6792, :destination_group_id => 332, :name => "France - Fixed"},
        "EGY" => {"FIX" => [144], :destination_id => 6352, :destination_group_id => 290, :name => "Egypt - Fixed"},
        "ESP" => {"FIX" => [150, 171], :destination_id => 3339, :destination_group_id => 1020, :name => "Spain - Fixed"}
      }
      s_prefix, subcode, name = ['EGY', 'FIX', 'import_csv_tabel_name']
      # expect sql with destination_id = 6352, before there was a bug - it was doing destination_id = 6792
      expected_sql = "UPDATE import_csv_tabel_name SET f_country_code = 1, short_prefix = 'EGY', f_subcodes = 'FIX', " +
        "destination_id = 6352, destination_group_id = 290, destination_name = 'Egypt - Fixed' WHERE id IN (144)"

      expect(Tariff.generate_sql_for_update(update, s_prefix, subcode, name)).to eq(expected_sql)
    end
  end
end
