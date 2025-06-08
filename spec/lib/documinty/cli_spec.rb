# spec/lib/documinty/cli_spec.rb
require 'spec_helper'
require 'documinty/cli'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Documinty::CLI do
  let(:tmpdir)        { Dir.mktmpdir }
  let(:store_dir)     { File.join(tmpdir, '.documinty') }
  let(:features_dir)  { File.join(store_dir, 'features') }

  # Run each example inside a temporary project directory
  around do |example|
    Dir.chdir(tmpdir) { example.run }
  end

  # Helper to invoke the CLI and capture stdout
  def run_cli(*args)
    capture_stdout { described_class.start(args) }
  end

  describe "#init" do
    it "creates .documinty directory, config.yml, and features/" do
      out = run_cli('init', '--codebase', 'myapp')
      expect(out).to match(/✅ Initialized documinty/)
      expect(Dir.exist?(features_dir)).to be true
      cfg = YAML.load_file(File.join(store_dir, 'config.yml'))
      expect(cfg['codebase_name']).to eq('myapp')
    end
  end

  describe "#feat" do
    before { run_cli('init') }

    it "creates a new feature file" do
      out = run_cli('feat', 'f1')
      expect(out).to include("✅ Created feature 'f1'")
      expect(File.exist?(File.join(features_dir, 'f1.yml'))).to be true
    end

    it "warns when feature already exists" do
      run_cli('feat', 'f1')
      out = run_cli('feat', 'f1')
      expect(out).to include("⚠️ Feature 'f1' already exists")
    end
  end

  describe "#features" do
    before { run_cli('init') }

    it "shows no features when none defined" do
      out = run_cli('features')
      expect(out).to include("No features defined.")
    end

    it "lists defined features" do
      run_cli('feat', 'a')
      run_cli('feat', 'b')
      out = run_cli('features')
      expect(out).to include("Defined features:")
      expect(out).to include("• a")
      expect(out).to include("• b")
    end
  end

  describe "#doc and #show" do
    before do
      run_cli('init')
      run_cli('feat', 'feat1')

      # Stub both prompts: description and initial methods
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter a brief description for this node⚙️:")
              .and_return("My desc")
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods for this node (or leave blank if none)🛠️:")
              .and_return("m1,m2")
    end

    it "documents a file and writes YAML" do
      out = run_cli('doc', 'foo.rb', '-f', 'feat1', '-n', 'model')
      expect(out).to include("✅ Documented foo.rb as model under 'feat1'")
      data = YAML.load_file(File.join(features_dir, 'feat1.yml'))
      entry = data['entries'].first
      expect(entry['path']).to eq('foo.rb')
      expect(entry['node']).to eq('model')
      expect(entry['methods']).to match_array(%w[m1 m2])
      expect(entry['description']).to eq('My desc')
    end

    it "shows documented file details" do
      run_cli('doc', 'foo.rb', '-f', 'feat1', '-n', 'model')
      out = run_cli('show', 'foo.rb')
      expect(out).to match(/File📄.*foo\.rb/)
      expect(out).to match(/Node type⚙️.*model/)
      expect(out).to match(/Methods🛠️.*m1, m2/)
      expect(out).to match(/Description📝.*My desc/)
    end
  end

  describe "#methods (add/remove)" do
    before do
      run_cli('init')
      run_cli('feat', 'feat1')

      # Stub doc prompts to produce an entry with no methods
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter a brief description for this node⚙️:")
              .and_return("")
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods for this node (or leave blank if none)🛠️:")
              .and_return("")
      run_cli('doc', 'x.rb', '-f', 'feat1', '-n', 'svc')
    end

    it "adds methods to an existing entry" do
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods to add to this node🛠️:")
              .and_return("a,b")
      out = run_cli('methods', 'x.rb', '-f', 'feat1', '-a', 'add')
      expect(out).to include("✅ Updated methods for x.rb under 'feat1': a, b")
    end

    it "removes methods from an existing entry" do
      # first add two methods
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods to add to this node🛠️:")
              .and_return("a,b")
      run_cli('methods', 'x.rb', '-f', 'feat1', '-a', 'add')

      # now remove one
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods to add to this node🛠️:")
              .and_return("a")
      out = run_cli('methods', 'x.rb', '-f', 'feat1', '-a', 'remove')
      expect(out).to include("✅ Updated methods for x.rb under 'feat1': b")
    end
  end

  describe "#describe and #update_description" do
    before do
      run_cli('init')
      run_cli('feat', 'feat1')

      # Stub doc prompts for creating an entry
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter a brief description for this node⚙️:")
              .and_return("orig")
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods for this node (or leave blank if none)🛠️:")
              .and_return("")
      run_cli('doc', 'y.rb', '-f', 'feat1', '-n', 'mdl')
    end

    it "shows only the description under a feature" do
      out = run_cli('describe', 'y.rb', '-f', 'feat1')
      expect(out).to include("📋 y.rb")
      expect(out).to include("orig")
    end

    it "updates the description interactively" do
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter a new description for 'y.rb' under 'feat1':")
              .and_return("newdesc")
      out = run_cli('update-description', 'y.rb', '-f', 'feat1')
      expect(out).to include("✅ Description updated for y.rb under 'feat1':")
      expect(out).to include("newdesc")
    end
  end

  describe "#untag" do
    before do
      run_cli('init')
      run_cli('feat', 'feat1')
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask).and_return("", "")
      run_cli('doc', 'z.rb', '-f', 'feat1', '-n', 'ctr')
    end

    it "removes an entry" do
      out = run_cli('untag', 'z.rb', '-f', 'feat1')
      expect(out).to match(/🗑️\s+Removed z\.rb/)
      data = YAML.load_file(File.join(features_dir, 'feat1.yml'))
      expect(data['entries']).to be_empty
    end
  end

  describe "#search_f" do
    before do
      run_cli('init')
      run_cli('feat', 'oss-thing')
      run_cli('feat', 'other')
      run_cli('feat', 'oss-banana')
    end

    it "lists matching features" do
      out = run_cli('search_f', 'oss')
      expect(out).to include("Matching features:")
      expect(out).to include("• oss-thing")
      expect(out).to include("• oss-banana")
    end

    it "reports when none match" do
      out = run_cli('search_f', 'zzz')
      expect(out).to include("❌ No features match 'zzz'")
    end
  end

  describe "#show_feature and #involved_f" do
    before do
      run_cli('init')
      run_cli('feat', 'f1')
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter a brief description for this node⚙️:")
              .and_return("d1")
      allow_any_instance_of(Documinty::CLI)
        .to receive(:ask)
              .with("Enter comma-separated methods for this node (or leave blank if none)🛠️:")
              .and_return("")
      run_cli('doc', 'a/b/c.rb', '-f', 'f1', '-n', 'svc')
      run_cli('doc', 'a/x.rb',   '-f', 'f1', '-n', 'svc')
    end

    it "lists entries under a feature" do
      out = run_cli('show_feature', 'f1')
      expect(out).to include("Entries for 'f1':")
      expect(out).to include("📄a/b/c.rb | (svc) – d1")
    end

    it "groups files by directory" do
      out = run_cli('involved_f', 'f1')
      expect(out).to include("🔖 f1")
      expect(out).to include("📁 a")
      expect(out).to include("📄 c.rb")
      expect(out).to include("📄 x.rb")
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
