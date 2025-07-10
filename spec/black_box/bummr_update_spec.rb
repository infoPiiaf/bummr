require "spec_helper"
require "jet_black"

RSpec.shared_examples "from root folder" do |path|
  let(:gemfile_path) { "#{path}Gemfile"}
  let(:rakefile_path) { "#{path}Rakefile"}
  let(:cd_if_necessary) { path ? "cd #{path} && " : nil }

  it "updates outdated gems" do
    session.create_file gemfile_path, <<~RUBY
    source "https://rubygems.org"
    gem "rake", "~> 10.0"
    gem "bummr", path: "#{bummr_gem_path}"
    RUBY

    session.create_file rakefile_path, <<~RUBY
    task :default do
      puts "Hello from the Rakefile"
    end
    RUBY

    expect(session.run("#{cd_if_necessary}bundle install --retry 3")).
      to be_a_success

    # Now allow newer versions of Rake to be installed
    session.run("sed -i.bak 's/, \"~> 10.0\"//' #{gemfile_path}")

    session.run("mkdir -p log")

    expect(session.run("#{git} init .")).
      to be_a_success.and have_stdout("Initialized empty Git repository")

    session.run("#{git} config user.name 'Bummr Test'")
    session.run("#{git} config user.email 'test@example.com'")

    expect(session.run("#{git} add . && #{git} commit -m 'Initial commit'")).
      to be_a_success.and have_stdout("Initial commit")

    session.run("#{git} checkout -b bummr-branch")

    update_result = session.run(
      "#{cd_if_necessary}bundle exec bummr update",
      stdin: "y\ny\ny\n",
      env: { EDITOR: nil, BUMMR_HEADLESS: "true" },
    )

    rake_gem_updated = /Update rake from 10\.\d\.\d to 1[1-9]\.\d\.\d/

    expect(update_result).
      to be_a_success.and have_stdout(rake_gem_updated)

    expect(update_result).to have_stdout("Passed the build!")

    expect(session.run("#{git} log")).
      to be_a_success.and have_stdout(rake_gem_updated)

    expect(session.run("#{cd_if_necessary}bundle show")).
      to be_a_success.and have_stdout(/rake\s\(1[1-9]/)
  end
end

describe "bummr update command" do
  let(:session) { JetBlack::Session.new(options: { clean_bundler_env: true }) }
  let(:bummr_gem_path) { File.expand_path("../../", __dir__) }
  let(:git) { "LANG=en_US git"}


  context "from root folder" do
    it_behaves_like "from root folder"
  end

  context "from included folder" do
    it_behaves_like "from root folder", "code/src/"
  end
end
