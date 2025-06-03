# lib/documinty/cli.rb
require 'thor'
require 'documinty/store'

module Documinty
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "init", "Initialize documinty in your project"
    option :codebase, aliases: '-c', desc: 'Custom codebase name'
    def init
      store.init(codebase_name: options[:codebase])
    end

    desc "feature NAME", "Create a new feature for tagging"
    def feat(name)
      begin
        store.add_feature(name)
        say "✅ Created feature '#{name}'", :green
      rescue Error => e
        say "⚠️ #{e.message}", :red
      end
    end

    desc "features", "List all defined features"
    def features
      fs = store.features
      if fs.empty?
        say "No features defined.", :yellow
      else
        say "Defined features:", :cyan
        fs.each { |f| say "• #{f}", :green }
      end
    end

    desc "document FILE", "Tag FILE under an existing feature"
    option :feature, aliases: '-f', required: true, desc: 'Feature name to group under'
    option :node,    aliases: '-n', required: true, desc: 'Node/type label'
    def doc(path)
      begin
        description = ask("Enter a brief description for this node⚙️:")
        methods_input = ask("Enter comma-separated methods for this node (or leave blank if none)🛠️:")
        method_syms = methods_input
                        .split(",")
                        .map(&:strip)
                        .reject(&:empty?)
                        .map(&:to_sym)

        entry = store.add_entry(
          path:        path,
          node:        options[:node],
          feature:     options[:feature],
          methods:     method_syms,
          timestamp:   Time.now.iso8601,
          description: description,
        )
        say "✅ Documented #{entry['path']} as #{entry['node']} under '#{entry['feature']}'", :green
      rescue Error => e
        say "❌ #{e.message}", :red
        exit(1)
      end
    end

    desc "show FILE", "Display documentation for FILE (node & feature)"
    option :feature, aliases: '-f', desc: 'Only show documentation under this feature'
    def show(path)
      entries = store.entries_for(path)

      # If a specific feature is requested, filter to those entries
      if options[:feature]
        entries = entries.select { |e| Array(e['features'] || e['feature']).include?(options[:feature]) }
      end

      if entries.empty?
        if options[:feature]
          say "❌ No documentation found for '#{path}' under feature '#{options[:feature]}'", :red
        else
          say "❌ No documentation found for '#{path}'", :red
        end
        exit(1)
      end

      entries.each do |e|
        label_color   = :cyan
        value_color   = :magenta

        # File
        say(
          set_color("File📄", label_color) +
            ": " +
            set_color(e['path'], value_color)
        )

        # Node type
        say(
          set_color("Node type⚙️", label_color) +
            ": " +
            set_color(e['node'], value_color)
        )

        # Features
        say(
          set_color("Features🏷️", label_color) +
            ": " +
            set_color(Array(e['features'] || e['feature']).join(", "), value_color)
        )

        # Description (only if present)
        unless e['description'].to_s.empty?
          say(
            set_color("Description📝", label_color) +
              ": " +
              set_color(e['description'], value_color)
          )
        end

        # Methods (only if present)
        if e['methods'] && !e['methods'].empty?
          say(
            set_color("Methods🛠️", label_color) +
              ": " +
              set_color(Array(e['methods']).join(", "), value_color)
          )
        end

        # Timestamp
        say(
          set_color("Tagged at⏰", label_color) +
            ": " +
            set_color(e['timestamp'], value_color)
        )

        say "-" * 40
      end
    end

    desc "untag FILE", "Remove FILE’s tag from an existing feature"
    option :feature, aliases: '-f', required: true, desc: "Feature name"
    def untag(path)
      begin
        removed = store.remove_entry(path: path, feature: options[:feature])
        removed.each do |e|
          say "🗑️  Removed #{e['path']} (#{e['node'] || e['node_type']}) from '#{options[:feature]}'", :green
        end
      rescue Error => e
        say "❌ #{e.message}", :red
        exit(1)
      end
    end

    desc "show-feature FEATURE", "List all files documented under FEATURE"
    def list_f(feature)
      begin
        entries = store.entries_for_feature(feature)
      rescue Error => e
        say "❌ #{e.message}", :red
        exit(1)
      end

      if entries.empty?
        say "No entries under '#{feature}'.", :red
      else
        say "Entries for '#{feature}':"
        entries.each do |e|
          say "• #{e['path']} (#{e['node']}) – #{e['description']}", :green
        end
      end
    end

    desc "show_feature_involved FEATURE", "Display files under FEATURE grouped by directory"
    def involved_f(feature)
      begin
        entries = store.entries_for_feature(feature)
      rescue Error => e
        say "❌ #{e.message}", :red
        exit(1)
      end

      if entries.empty?
        say "No entries under '#{feature}'.", :yellow
        return
      end

      # Print the feature name in bold cyan
      say "🔖 #{feature}", :cyan

      # Group entries by their containing directory
      grouped = entries.group_by { |e| File.dirname(e['path']) }

      grouped.each do |dir, entries_in_dir|
        # Print each directory line with a folder emoji, in green
        say "📁 #{dir}", :green

        entries_in_dir.each do |e|
          # Print each filename line with a file emoji, indented, in green
            say "    📄 #{File.basename(e['path'])}", :green
        end
      end
    end


    desc "search_f QUERY", "List all features containing QUERY"
    def search_f(query)
      matches = store.features.select { |f| f.include?(query) }
      if matches.empty?
        say "❌ No features match '#{query}'", :red
      else
        say "Matching features:", :cyan
        matches.each { |f| say "• #{f}", :green }
      end
    end

    private

    def store
      @store ||= Store.new(Dir.pwd)
    end
  end
end
