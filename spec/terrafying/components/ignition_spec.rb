require 'terrafying'
require 'terrafying/components/ignition'


RSpec.describe Terrafying::Components::Ignition, '#container_unit' do
  it 'creates a unit file' do
    container_unit = Terrafying::Components::Ignition.container_unit("app", "app:latest")

    expect(container_unit[:name]).to eq("app.service")
    expect(container_unit[:contents]).to match(/app:latest/)
  end

  it 'sets up host networking' do
    container_unit = Terrafying::Components::Ignition.container_unit("app", "app:latest", { host_networking: true })

    expect(container_unit[:contents]).to match(/--net=host/)
  end

  it 'sets up privileged mode' do
    container_unit = Terrafying::Components::Ignition.container_unit("app", "app:latest", { privileged: true })

    expect(container_unit[:contents]).to match(/--privileged/)
  end

  it 'adds environment variables' do
    container_unit = Terrafying::Components::Ignition.container_unit(
      "app", "app:latest", {
        environment_variables: [ "FOO=bar" ],
      }
    )

    expect(container_unit[:contents]).to match(/-e FOO=bar/)
  end

  it 'adds volumes' do
    container_unit = Terrafying::Components::Ignition.container_unit(
      "app", "app:latest", {
        volumes: [ "/tmp:/tmp:ro" ],
      }
    )

    expect(container_unit[:contents]).to match(/-v \/tmp:\/tmp:ro/)
  end

  it 'adds arguments' do
    container_unit = Terrafying::Components::Ignition.container_unit(
      "app", "app:latest", {
        arguments: [ "/bin/bash", "-c 'echo hi'" ],
      }
    )

    expect(container_unit[:contents]).to match(/\/bin\/bash\s+\\\n-c 'echo hi'/)
  end

  it 'adds required units' do
    container_unit = Terrafying::Components::Ignition.container_unit(
      "app", "app:latest", {
        require_units: [ "disk.mount", "database.service" ],
      }
    )

    expect(container_unit[:contents]).to match(/Requires=disk.mount database.service/)
    expect(container_unit[:contents]).to match(/After=disk.mount database.service/)
  end

end

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

  it "adds in unit files" do
    user_data = Terrafying::Components::Ignition.generate(
      {
        units: [{ name: "foo.service", contents: "LOOL" }],
      }
    )

    units = JSON.parse(user_data, { symbolize_names: true })[:systemd][:units]

    expect(units.any? do |unit|
             unit == {
               name: 'foo.service',
               enabled: true,
               contents: "LOOL"
             }
           end).to be true
  end

  it "adds in drops not just contents into units" do
    user_data = Terrafying::Components::Ignition.generate(
      {
        units: [{ name: "docker.service", dropins: [{contents: "LOL", name: "10-lol.conf"}] }],
      }
    )

    units = JSON.parse(user_data, { symbolize_names: true })[:systemd][:units]

    expect(units.any? do |unit|
             unit == {
               name: 'docker.service',
               enabled: true,
               dropins: [{contents: "LOL", name: "10-lol.conf"}],
             }
           end).to be true
  end

  it "adds in files" do
    user_data = Terrafying::Components::Ignition.generate(
      {
        files: [{ path: "/etc/app/app.conf", mode: "0999", contents: "LOOL" }],
      }
    )

    files = JSON.parse(user_data, { symbolize_names: true })[:storage][:files]

    expect(files.any? do |file|
             file == {
               filesystem: "root",
               mode: "0999",
               path: "/etc/app/app.conf",
               user: { id: 0 },
               group: { id: 0 },
               contents: { source: "data:;base64,TE9PTA==" },
             }
           end).to be true
  end

  it "passes through the ssh_group" do
    user_data = Terrafying::Components::Ignition.generate(
      {
        ssh_group: "smurfs",
      }
    )

    units = JSON.parse(user_data, { symbolize_names: true })[:systemd][:units]

    usersync_unit = units.select { |u| u[:name] == "usersync.service" }.first

    expect(usersync_unit[:contents]).to match(/-g="smurfs"/)
  end

  it "setups keypairs/cas properly" do
    ca = Terrafying::Components::SelfSignedCA.create("great-ca", "some-bucket")
    keypair = ca.create_keypair("foo")

    user_data = Terrafying::Components::Ignition.generate(
      {
        keypairs: [ keypair ],
      }
    )

    units = JSON.parse(user_data, { symbolize_names: true })[:systemd][:units]

    certs_unit = units.select { |u| u[:name] == "download-certs.service" }.first

    paths = certs_unit[:contents].scan(/\/etc\/ssl\/[^\/]+\/[a-z\.]+[\/\.][a-z\.]+/)

    expect(paths).to include("/etc/ssl/great-ca/ca.cert", "/etc/ssl/great-ca/foo/key", "/etc/ssl/great-ca/foo/cert")
  end
end
