FactoryGirl.define do

  factory :rate do
    name 'reitas'
    effective_from '2012-12-14 08:15:00'.to_time
  end

  factory :tariff, class: Tariff do
    name 'factory tariff'

    after(:create) do |tariff|
      create_list(:rate, 2, tariff: tariff)
    end
  end

  factory :user do
    usertype 'user'
    currency_id 1
    username 'factory user'
    registration true
    time_zone 'Vilnius'

    after(:create) do |user|
      create_list(:tariff, 1, owner: user)
    end
  end

  factory :manager, class: User do
    usertype 'manager'
    first_name 'Lary'
    password 'Bobinsky'
    currency_id 1
    registration true
    username 'factory manager'
    time_zone 'Vilnius'

    after(:create) do |user|
      create_list(:tariff, 1, owner: user)
    end
  end

  factory :manager_group do
    name 'factory manager group'

    after(:create) do |manager_group|
      create_list(:manager, 1, manager_group: manager_group)
    end

    factory :manager_group_with_tariffs_right do

      after(:create) do |manager_group|
        manager_group.update_rights([['BILLING_Tariffs', 2]])
      end
    end
  end

end