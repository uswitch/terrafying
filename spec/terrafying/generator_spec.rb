
require 'terrafying/generator'

RSpec.describe Terrafying::Ref do

  context "to_s" do
    it "should return an interpolated string" do
      ref = Terrafying::Ref.new("var.thingy")

      expect(ref.to_s).to eq("${var.thingy}")
    end
  end

  context "downcase" do
    it "should wrap it in lower" do
      ref = Terrafying::Ref.new("var.thingy")

      expect(ref.downcase.to_s).to eq("${lower(var.thingy)}")
    end
  end

  context "strip" do
    it "should wrap it in trimspace" do
      ref = Terrafying::Ref.new("var.thingy")

      expect(ref.strip.to_s).to eq("${trimspace(var.thingy)}")
    end
  end

  it "should stack functions" do
    ref = Terrafying::Ref.new("var.thingy")

    expect(ref.downcase.strip.to_s).to eq("${trimspace(lower(var.thingy))}")
  end

end

RSpec.describe Terrafying::Context do

  context "output_of" do

    it "should use a ref" do
      context = Terrafying::Context.new

      ref = context.output_of(:aws_security_group, "foo", "bar").downcase

      expect("#{ref}").to eq("${lower(aws_security_group.foo.bar)}")
    end

  end

  context "id_of" do
    it "should use a ref" do
      context = Terrafying::Context.new

      ref = context.id_of(:aws_security_group, "foo").downcase

      expect("#{ref}").to eq("${lower(aws_security_group.foo.id)}")
    end
  end

end
