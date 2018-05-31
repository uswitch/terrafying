
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

  it "should be comparable" do
    refs = [
      Terrafying::Ref.new("var.b"),
      Terrafying::Ref.new("var.a"),
    ]

    expect(refs.sort[0].to_s).to eq("${var.a}")
  end

  it "implements equality" do
    a = Terrafying::Ref.new("var.a")
    a2 = Terrafying::Ref.new("var.a")
    b = Terrafying::Ref.new("var.b")

    expect(a == a).to be true
    expect(a == a2).to be true
    expect(a == b).to be false
  end

end

RSpec.describe Terrafying::Context do

  context "provider" do

    it "should output a string" do
      context = Terrafying::Context.new

      provider = context.provider(:aws, {})

      expect(provider).to eq("aws")
    end

    it "should output a string with alias" do
      context = Terrafying::Context.new

      provider = context.provider(:aws, alias: 'west')

      expect(provider).to eq("aws.west")
    end

    it 'should append providers to an array' do
      context = Terrafying::Context.new

      context.provider(:aws, alias: 'west')

      providers = context.output_with_children['provider']

      expect(providers).to include(
        a_hash_including('aws' => { alias: 'west' })
      )
    end

    it 'should append multiple providers to an array' do
      context = Terrafying::Context.new

      context.provider(:aws, alias: 'west')
      context.provider(:aws, alias: 'east')

      providers = context.output_with_children['provider']

      expect(providers).to include(
        a_hash_including('aws' => { alias: 'west' }),
        a_hash_including('aws' => { alias: 'east' })
      )
    end

    it 'should not allow duplicate providers' do
      context = Terrafying::Context.new

      context.provider(:aws, alias: 'west')
      context.provider(:aws, alias: 'west')

      providers = context.output_with_children['provider']

      expect(providers.size).to eq(1)
    end

    it 'should reject duplicate providers on name + alias' do
      context = Terrafying::Context.new

      context.provider(:aws, alias: 'west', region: 'eu-west-1')
      expect {
        context.provider(:aws, alias: 'west', region: 'eu-west-2')
      }.to raise_error(/aws\.west/)

    end

    it 'should merge nested contexts with providers' do
      context = Terrafying::Context.new
      nested_context = Terrafying::Context.new

      context.provider(:aws, alias: 'west', region: 'eu-west-1')
      nested_context.provider(:aws, alias: 'west', region: 'eu-west-1')
      nested_context.provider(:aws, alias: 'east', region: 'eu-east-1')
      context.add! nested_context

      providers = context.output_with_children['provider']

      expect(providers.size).to eq(2)
      expect(providers).to include(
        a_hash_including('aws' => { alias: 'west', region: 'eu-west-1' }),
        a_hash_including('aws' => { alias: 'east', region: 'eu-east-1' })
      )
    end

  end

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
