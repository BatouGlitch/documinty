# spec/lib/documinty/store_spec.rb
require 'spec_helper'
require 'documinty/store'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Documinty::Store do
  let(:root)        { Dir.mktmpdir }
  let(:store)       { described_class.new(root) }
  let(:base)        { File.join(root, '.documinty') }
  let(:features_dir){ File.join(base, 'features') }
  let(:config_file) { File.join(base, 'config.yml') }

  after do
    FileUtils.remove_entry(root) if Dir.exist?(root)
  end

  describe "#init" do
    it "creates .documinty/config.yml and features directory" do
      store.init(codebase_name: 'myapp')
      expect(Dir.exist?(features_dir)).to be true
      expect(File.exist?(config_file)).to be true
      cfg = YAML.load_file(config_file)
      expect(cfg['codebase_name']).to eq('myapp')
    end
  end

  describe "#add_feature" do
    before { store.init }

    it "creates a new feature file and returns the name" do
      result = store.add_feature('feat1')
      expect(result).to eq('feat1')
      path = File.join(features_dir, "feat1.yml")
      expect(File.exist?(path)).to be true
      expect(YAML.load_file(path)).to eq('entries' => [])
    end

    it "raises an error if the feature already exists" do
      store.add_feature('feat1')
      expect { store.add_feature('feat1') }.to raise_error(Documinty::Error, /already exists/)
    end
  end

  describe "#features" do
    before { store.init }

    it "returns an empty array if no features exist" do
      expect(store.features).to eq([])
    end

    it "lists all feature names" do
      store.add_feature('a')
      store.add_feature('b')
      expect(store.features.sort).to eq(%w[a b])
    end
  end

  describe "entries API" do
    let(:feature)    { 'feat1' }
    let(:file_path)  { 'app/models/user.rb' }
    let(:timestamp)  { '2025-06-08T12:00:00Z' }
    let(:description){ 'User model' }

    before do
      store.init
      store.add_feature(feature)
    end

    describe "#add_entry" do
      it "adds an entry and returns it" do
        entry = store.add_entry(
          path:        file_path,
          node:        :model,
          feature:     feature,
          methods:     [:foo, :bar],
          timestamp:   timestamp,
          description: description
        )
        expect(entry['path']).to eq(file_path)
        expect(entry['node']).to eq('model')
        expect(entry['feature']).to eq(feature)
        expect(entry['methods']).to match_array(%w[foo bar])
        expect(entry['description']).to eq(description)
        expect(entry['timestamp']).to eq(timestamp)
      end

      it "raises if the feature does not exist" do
        expect {
          store.add_entry(path: file_path, node: :model,
                          feature: 'nope', methods: [], timestamp: timestamp, description: '')
        }.to raise_error(Documinty::Error, /does not exist/)
      end
    end

    describe "#entries_for" do
      it "returns entries across all features for a given file" do
        store.add_entry(path: file_path, node: :model, feature: feature,
                        methods: [], timestamp: timestamp, description: description)
        expect(store.entries_for(file_path).size).to eq(1)
      end

      it "returns empty if no matching entries" do
        expect(store.entries_for('other.rb')).to be_empty
      end
    end

    describe "#entries_for_feature" do
      it "returns entries for a specific feature" do
        store.add_entry(path: file_path, node: :model, feature: feature,
                        methods: [], timestamp: timestamp, description: description)
        expect(store.entries_for_feature(feature).size).to eq(1)
      end

      it "raises if the feature does not exist" do
        expect { store.entries_for_feature('nope') }.to raise_error(Documinty::Error)
      end
    end

    describe "#remove_entry" do
      before do
        store.add_entry(path: file_path, node: :model, feature: feature,
                        methods: [], timestamp: timestamp, description: description)
      end

      it "removes and returns the entry" do
        removed = store.remove_entry(path: file_path, feature: feature)
        expect(removed.first['path']).to eq(file_path)
        expect(store.entries_for_feature(feature)).to be_empty
      end

      it "raises if feature does not exist" do
        expect { store.remove_entry(path: file_path, feature: 'nope') }.to raise_error(Documinty::Error)
      end

      it "raises if no entries under that feature" do
        store.remove_entry(path: file_path, feature: feature)
        expect { store.remove_entry(path: file_path, feature: feature) }.to raise_error(Documinty::Error)
      end
    end
  end

  describe "#methods" do
    let(:feature)   { 'feat1' }
    let(:file_path) { 'file.rb' }

    before do
      store.init
      store.add_feature(feature)
      store.add_entry(path: file_path, node: :service, feature: feature,
                      methods: [:a], timestamp: '2025', description: '')
    end

    it "adds new methods without duplication" do
      entry = store.methods(path: file_path, feature: feature,
                            new_methods: %i[b a], action: :add)
      expect(entry['methods']).to match_array(%w[a b])
    end

    it "removes specified methods" do
      entry = store.methods(path: file_path, feature: feature,
                            new_methods: %i[a], action: :remove)
      expect(entry['methods']).to eq([])
    end

    it "raises if the entry does not exist" do
      expect {
        store.methods(path: 'no.rb', feature: feature,
                      new_methods: [:x], action: :add)
      }.to raise_error(Documinty::Error)
    end
  end

  describe "#update_description" do
    let(:feature)   { 'feat1' }
    let(:file_path) { 'file.rb' }

    before do
      store.init
      store.add_feature(feature)
      store.add_entry(path: file_path, node: :model, feature: feature,
                      methods: [], timestamp: '2025', description: 'old')
    end

    it "updates and persists the description" do
      entry = store.update_description(path: file_path,
                                       feature: feature,
                                       new_description: 'new desc')
      expect(entry['description']).to eq('new desc')

      # reload YAML to confirm persistence
      data = YAML.load_file(File.join(root, '.documinty', 'features', "#{feature}.yml"))
      expect(data['entries'].first['description']).to eq('new desc')
    end

    it "raises if the entry does not exist" do
      expect {
        store.update_description(path: 'no.rb',
                                 feature: feature,
                                 new_description: 'x')
      }.to raise_error(Documinty::Error)
    end
  end
end
