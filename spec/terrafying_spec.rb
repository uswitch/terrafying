
require 'terrafying'

RSpec.describe Terrafying::Output do

  context "to_s" do
    it "should return an interpolated string" do
      out = Terrafying::Output.new("var.thingy")

      expect(out.to_s).to eq("${var.thingy}")
    end
  end

  context "downcase" do
    it "should wrap it in lower" do
      out = Terrafying::Output.new("var.thingy")

      expect(out.downcase.to_s).to eq("${lower(var.thingy)}")
    end
  end

  context "strip" do
    it "should wrap it in trimspace" do
      out = Terrafying::Output.new("var.thingy")

      expect(out.strip.to_s).to eq("${trimspace(var.thingy)}")
    end
  end

  it "should stack functions" do
    out = Terrafying::Output.new("var.thingy")

    expect(out.downcase.strip.to_s).to eq("${trimspace(lower(var.thingy))}")
  end

  it "should be comparable" do
    outputs = [
      Terrafying::Output.new("var.b"),
      Terrafying::Output.new("var.a"),
    ]

    expect(outputs.sort[0].to_s).to eq("${var.a}")
  end

  it "implements equality" do
    a = Terrafying::Output.new("var.a")
    a2 = Terrafying::Output.new("var.a")
    b = Terrafying::Output.new("var.b")

    expect(a == a).to be true
    expect(a == a2).to be true
    expect(a == b).to be false
  end

end

RSpec.describe Terrafying::Reference do

  it "should output" do
    ref = Terrafying::Reference.new("aws_kms_key", "secret")

    out = ref["arn"]

    expect(out).to be_a(Terrafying::Output)
    expect(out.to_s).to eq("${aws_kms_key.secret.arn}")
  end

  it "should default to id" do
    ref = Terrafying::Reference.new("aws_kms_key", "secret")

    expect(ref.to_s).to eq("${aws_kms_key.secret.id}")
  end

  it "should't let you try and set" do
    ref = Terrafying::Reference.new("aws_kms_key", "secret")

    expect {
      ref["arn"] = "foo"
    }.to raise_error RuntimeError
  end

  it "should prefix with data when appropriate" do
    ref = Terrafying::Reference.new("aws_kms_key", "secret", kind: "data")

    expect(ref.to_s).to eq("${data.aws_kms_key.secret.id}")
  end

end

RSpec.describe Terrafying::Context do

  context "resource" do
    it "should use a reference" do
      context = Terrafying::Context.new

      key = context.resource(:aws_kms_key, "secret", {})

      expect(key).to be_a(Terrafying::Reference)
      expect(key["arn"].downcase).to eq("${lower(aws_kms_key.secret.arn)}")
    end
  end

  context "data" do
    it "should use a reference" do
      context = Terrafying::Context.new

      key = context.data(:aws_kms_key, "secret", {})

      expect(key).to be_a(Terrafying::Reference)
      expect(key["arn"].downcase).to eq("${lower(data.aws_kms_key.secret.arn)}")
    end
  end

  context "provider" do
    it "should provide a string reference" do
      context = Terrafying::Context.new

      key = context.provider("aws", {})

      expect(key).to eq("aws")
    end

    it "should provide a string reference with alias" do
      context = Terrafying::Context.new

      key = context.provider("aws", { alias: "west" })

      expect(key).to eq("aws.west")
    end
  end

  context "output_of" do
    it "should use an output" do
      context = Terrafying::Context.new

      arn = context.output_of(:aws_kms_key, "secret", "arn")

      expect(arn).to be_a(Terrafying::Output)
      expect(arn.downcase).to eq("${lower(aws_kms_key.secret.arn)}")
    end
  end

end
