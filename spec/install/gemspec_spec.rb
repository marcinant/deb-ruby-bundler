require "spec_helper"

describe "bundle install from an existing gemspec" do

  before(:each) do
    build_gem "bar", :to_system => true
    build_gem "bar-dev", :to_system => true
  end

  it "should install runtime and development dependencies" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("Gemfile", "source :rubygems\ngemspec")
      s.add_dependency "bar", "=1.0.0"
      s.add_development_dependency "bar-dev", '=1.0.0'
    end
    install_gemfile <<-G
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}'
    G

    should_be_installed "bar 1.0.0"
    should_be_installed "bar-dev 1.0.0", :groups => :development
  end

  it "that is hidden should install runtime and development dependencies" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("Gemfile", "source :rubygems\ngemspec")
      s.add_dependency "bar", "=1.0.0"
      s.add_development_dependency "bar-dev", '=1.0.0'
    end
    FileUtils.mv tmp.join('foo', 'foo.gemspec'), tmp.join('foo', '.gemspec')

    install_gemfile <<-G
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}'
    G

    should_be_installed "bar 1.0.0"
    should_be_installed "bar-dev 1.0.0", :groups => :development
  end

  it "should handle a list of requirements" do
    build_gem "baz", "1.0", :to_system => true
    build_gem "baz", "1.1", :to_system => true

    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("Gemfile", "source :rubygems\ngemspec")
      s.add_dependency "baz", ">= 1.0", "< 1.1"
    end
    install_gemfile <<-G
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}'
    G

    should_be_installed "baz 1.0"
  end

  it "should raise if there are no gemspecs available" do
    build_lib("foo", :path => tmp.join("foo"), :gemspec => false)

    error = install_gemfile(<<-G, :expect_err => true)
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}'
    G
    error.should match(/There are no gemspecs at #{tmp.join('foo')}/)
  end

  it "should raise if there are too many gemspecs available" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("foo2.gemspec", "")
    end

    error = install_gemfile(<<-G, :expect_err => true)
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}'
    G
    error.should match(/There are multiple gemspecs at #{tmp.join('foo')}/)
  end

  it "should pick a specific gemspec" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("foo2.gemspec", "")
      s.add_dependency "bar", "=1.0.0"
      s.add_development_dependency "bar-dev", '=1.0.0'
    end

    install_gemfile(<<-G, :expect_err => true)
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}', :name => 'foo'
    G

    should_be_installed "bar 1.0.0"
    should_be_installed "bar-dev 1.0.0", :groups => :development
  end

  it "should use a specific group for development dependencies" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("foo2.gemspec", "")
      s.add_dependency "bar", "=1.0.0"
      s.add_development_dependency "bar-dev", '=1.0.0'
    end

    install_gemfile(<<-G, :expect_err => true)
      source "file://#{gem_repo2}"
      gemspec :path => '#{tmp.join("foo")}', :name => 'foo', :development_group => :dev
    G

    should_be_installed "bar 1.0.0"
    should_not_be_installed "bar-dev 1.0.0", :groups => :development
    should_be_installed "bar-dev 1.0.0", :groups => :dev
  end

  it "should match a lockfile even if the gemspec defines development dependencies" do
    build_lib("foo", :path => tmp.join("foo")) do |s|
      s.write("Gemfile", "source 'file://#{gem_repo1}'\ngemspec")
      s.add_dependency "actionpack", "=2.3.2"
      s.add_development_dependency "rake", '=0.8.7'
    end

    Dir.chdir(tmp.join("foo")) do
      bundle "install"
      # This should really be able to rely on $stderr, but, it's not written
      # right, so we can't. In fact, this is a bug negation test, and so it'll
      # ghost pass in future, and will only catch a regression if the message
      # doesn't change. Exit codes should be used correctly (they can be more
      # than just 0 and 1).
      output = bundle("install --deployment")
      output.should_not match(/You have added to the Gemfile/)
      output.should_not match(/You have deleted from the Gemfile/)
      output.should_not match(/install in deployment mode after changing/)
    end
  end

  it "should evaluate the gemspec in its directory" do
    build_lib("foo", :path => tmp.join("foo"))
    File.open(tmp.join("foo/foo.gemspec"), "w") do |s|
      s.write "raise 'ahh' unless Dir.pwd == '#{tmp.join("foo")}'"
    end

    install_gemfile <<-G, :expect_err => true
      gemspec :path => '#{tmp.join("foo")}'
    G
    @err.should_not match(/ahh/)
  end

end
