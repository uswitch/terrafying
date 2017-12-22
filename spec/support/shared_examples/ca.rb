shared_examples "a CA" do

  it { is_expected.to respond_to(:create) }
  it { is_expected.to respond_to(:create_keypair) }
  it { is_expected.to respond_to(:create_keypair_in) }
  it { is_expected.to respond_to(:reference_keypair) }
  it { is_expected.to respond_to(:<=>) }

  let :ca_name do
    "some-ca"
  end

  let :bucket_name do
    "a-bucket"
  end

  before do
    @ca = described_class.create(ca_name, bucket_name)
  end

  describe ".create" do

    it "should put the cert in s3" do
      ca_cert = @ca.output["resource"]["aws_s3_bucket_object"].select { |_, obj|
        obj[:key] == "/#{ca_name}/ca.cert" && obj[:bucket] == bucket_name
      }

      expect(ca_cert.count).to eq(1)
      expect(@ca.source).to eq("s3://#{bucket_name}/#{ca_name}/ca.cert")
    end

    it "should populate name" do
      expect(@ca.name).to eq(ca_name)
    end

  end

  describe ".create_keypair_in" do

    it "should put stuff in the right context" do
      ctx = Terrafying::Context.new

      keypair = @ca.create_keypair_in(ctx, "foo")

      resource_names = keypair[:resources].map { |r| r.split(".")[1] }

      expect(ctx.output["resource"]["aws_s3_bucket_object"].keys).to include(*resource_names)
      expect(@ca.output["resource"]["aws_s3_bucket_object"].keys).to_not include(*resource_names)
    end

  end

  describe ".create_keypair" do

    it "should reference the right bucket objects in output" do
      keypair = @ca.create_keypair("foo")

      cert_object = @ca.output["resource"]["aws_s3_bucket_object"].select { |_, obj|
        File.join("s3://", obj[:bucket], obj[:key]) == keypair[:source][:cert]
      }.first
      key_object = @ca.output["resource"]["aws_s3_bucket_object"].select { |_, obj|
        File.join("s3://", obj[:bucket], obj[:key]) == keypair[:source][:key]
      }.first

      expect(cert_object).to_not be nil
      expect(key_object).to_not be nil
    end

    it "should reference the correct resources in the IAM statement" do
      keypair = @ca.create_keypair("foo")

      objects = keypair[:iam_statement][:Resource].map { |arn|
        path = arn.split(':::')[1]

        _, obj = @ca.output["resource"]["aws_s3_bucket_object"].select { |_, obj|
          File.join(obj[:bucket], obj[:key]) == path
        }.first

        obj
      }

      expect(objects).to all( be_a Hash )
    end

    it "should reference resources that exist" do
      keypair = @ca.create_keypair("foo")

      expect(keypair[:resources].all? { |r|
        type, name = r.split(".")
        @ca.output["resource"][type].has_key? name
      }).to be true
    end

  end

  it "should be sortable" do
    a = described_class.create("a", "a-bucket")
    b = described_class.create("b", "b-bucket")
    c = described_class.create("c", "c-bucket")

    unsorted = [b, c, a]
    expect(unsorted.sort).to eq([a, b, c])
  end

end
