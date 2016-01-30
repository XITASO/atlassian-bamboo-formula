require "serverspec"

set :backend, :exec

describe service("atlassian-bamboo") do
  it { should be_enabled }
  it { should be_running }
end

describe port("8009") do
  it { should be_listening }
end

describe port("8085") do
  it { should be_listening }
end

describe command('curl -L localhost:8085') do
  its(:stdout) { should contain('Welcome to Atlassian Bamboo continuous integration server') }
end
