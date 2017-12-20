require 'terrafying'
require 'terrafying/components/letsencrypt'


RSpec.describe Terrafying::Components::LetsEncrypt do

  it_behaves_like "a CA"

end
