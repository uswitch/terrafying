require 'terrafying'
require 'terrafying/components/zone'

RSpec.describe Terrafying::Components::Zone, '#add_cname_in' do
  context 'with new record' do
    it 'creates a new aws route53 name record' do
      context = Terrafying::Context.new
      zone = Terrafying::Components::Zone.create('rspec.usw.co')

      zone.add_cname_in(context, 'test', 'test.target')

      cname_record = context.output['resource']['aws_route53_record']['test-rspec-usw-co']
      expect(cname_record).to include(
        {
          name: 'test.rspec.usw.co',
          type: 'CNAME',
          ttl:  300,
          records: ['test.target']
        }
      )
    end
  end
end
