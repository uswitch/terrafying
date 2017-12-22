require 'terrafying'
require 'terrafying/components/selfsignedca'


RSpec.describe Terrafying::Components::SelfSignedCA do

  it_behaves_like "a CA"

end
