FactoryBot.define do
  factory :audit_log do
    trackable { nil }
    action { 'MyString' }
    description { 'MyText' }
  end
end
