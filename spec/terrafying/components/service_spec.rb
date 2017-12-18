require 'terrafying'
require 'terrafying/components/service'

RSpec.describe Terrafying::Components::Service, '#user_data' do
  context 'with volumes' do
    it 'creates userdata with correct mountpoints' do
      options = {
        volumes: [{ name: 'test_vol', mount: '/var/test', device: '/dev/test' }]
      }
      service = Terrafying::Components::Service.new

      user_data_ign = service.user_data(options)

      units = JSON.parse(user_data_ign, { symbolize_names: true })[:systemd][:units]

      expect(units.any? do |unit|
        unit == {
          name: 'var-test.mount',
          enabled: true,
          contents: "[Mount]\nWhat=/dev/test\nWhere=/var/test\nType=ext4\n"
        }
      end).to be true
    end
  end
end
