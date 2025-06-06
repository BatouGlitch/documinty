# lib/documinty/store.rb
require 'fileutils'
require 'yaml'
require 'time'

module Documinty
  class Store
    CONFIG_DIR    = '.documinty'.freeze
    CONFIG_FILE   = 'config.yml'.freeze
    FEATURES_DIR  = 'features'.freeze
    FEATURE_EXT   = '.yml'.freeze

    def initialize(root = Dir.pwd)
      @root          = root
      @base_path     = File.join(@root, CONFIG_DIR)
      @features_path = File.join(@base_path, FEATURES_DIR)
    end

    # ─── bootstrap ────────────────────────────────────────────────────────────
    # Create .documinty/, write config.yml, and make the features/ dir
    def init(codebase_name: nil)
      FileUtils.mkdir_p(@features_path)
      cfg = { 'codebase_name' => (codebase_name || default_codebase_name) }
      File.write(File.join(@base_path, CONFIG_FILE), cfg.to_yaml)
      puts "✅ Initialized documinty at #{File.join(@root, CONFIG_DIR)}"
    end

    # ─── Features API ─────────────────────────────────────────────────────────
    # Create a new feature file (errors if it already exists)
    def add_feature(name)
      path = feature_file(name)
      raise Error, "Feature '#{name}' already exists" if File.exist?(path)

      File.write(path, { 'entries' => [] }.to_yaml)
      name
    end

    # List all defined feature names
    def features
      Dir.glob(File.join(@features_path, "*#{FEATURE_EXT}"))
         .map { |f| File.basename(f, FEATURE_EXT) }
    end

    # ─── Entries API ──────────────────────────────────────────────────────────
    # Tag a file under a specific feature
    def add_entry(path:, node:, feature:, methods: [], timestamp:, description: '')
      file = feature_file(feature)
      raise Error, "Feature '#{feature}' does not exist" unless File.exist?(file)

      data    = YAML.load_file(file) || {}
      entries = (data['entries'] ||= [])
      entry   = {
        'path'        => path,
        'node'        => node.to_s,
        'feature'     => feature,
        'methods'     => Array(methods).map(&:to_s),
        'description' => description.to_s.strip,
        'timestamp'   => timestamp
      }
      entries << entry
      File.write(file, data.to_yaml)
      entry
    end

    # Return all entries across *all* features for a given file path
    def entries_for(path)
      results = []
      features.each do |feature|
        file = feature_file(feature)
        next unless File.exist?(file)
        data = YAML.load_file(file) || {}
        (data['entries'] || []).each do |e|
          if e['path'] == path
            e['feature'] ||= feature
            results << e
          end
        end
      end
      results
    end

    # Remove an entry for path under one feature
    def remove_entry(path:, feature:)
      file = feature_file(feature)
      raise Error, "Feature '#{feature}' does not exist" unless File.exist?(file)

      data    = YAML.load_file(file) || {}
      entries = data['entries'] || []
      removed = entries.select { |e| e['path'] == path }
      raise Error, "No entries for '#{path}' under feature '#{feature}'" if removed.empty?

      data['entries'] = entries.reject { |e| e['path'] == path }
      File.write(file, data.to_yaml)
      removed
    end

    # Shows all the files listed under a feature
    def entries_for_feature(feature)
      file = feature_file(feature)
      raise Error, "Feature '#{feature}' does not exist" unless File.exist?(file)

      data = YAML.load_file(file) || {}
      data['entries'] || []
    end

    # Add one or more methods to a documented file under a given feature
    # @param path [String]       relative file path
    # @param feature [String]    feature name (must already exist on that entry)
    # @param new_methods [Array<Symbol>]  list of symbols to add
    # @return [Hash] the updated entry
    def add_methods(path:, feature:, new_methods:)
      file = feature_file(feature)
      raise Error, "Feature '#{feature}' does not exist" unless File.exist?(file)

      data = YAML.load_file(file) || {}
      entries = data['entries'] || []

      # Find the exact entry by path + feature
      entry = entries.find { |e| e['path'] == path && e['feature'] == feature }
      unless entry
        raise Error, "No documentation found for '#{path}' under feature '#{feature}'"
      end

      # Merge existing methods (strings) with new ones, avoid duplicates
      existing = Array(entry['methods']).map(&:to_s)
      merged  = (existing + new_methods.map(&:to_s)).uniq
      entry['methods'] = merged

      File.write(file, data.to_yaml)
      entry
    end

    private

    # Build the path to a feature’s YAML file
    def feature_file(name)
      File.join(@features_path, "#{name}#{FEATURE_EXT}")
    end

    def default_codebase_name
      File.basename(File.expand_path(@root))
    end
  end
end
