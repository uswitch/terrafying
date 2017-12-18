require 'terrafying'
require 'terrafying/components/ignition'

RSpec.describe Terrafying::Components::Ignition, '#generate' do
  context 'with volumes' do
    it 'creates userdata with correct mountpoints' do
      options = {
        volumes: [{ name: 'test_vol', mount: '/var/test', device: '/dev/test' }]
      }

      user_data_ign = Terrafying::Components::Ignition.generate(options)

      units = JSON.parse(user_data_ign, { symbolize_names: true })[:systemd][:units]

      expect(units.any? do |unit|
        unit == {
          name: 'var-test.mount',
          enabled: true,
          contents: "[Install]\nWantedBy=local-fs.target\n\n[Unit]\nBefore=docker.service\n\n[Mount]\nWhat=/dev/test\nWhere=/var/test\nType=ext4\n"
        }
      end).to be true
    end
  end
end
