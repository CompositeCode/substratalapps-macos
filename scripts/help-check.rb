#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks a built Help Center against the app, so the app can never link to a
# help page that doesn't exist.
#
#   scripts/help-check.rb SITE_DIR
#
# Fails when:
#   - a screen in the catalog has no page at screens/<id>/
#   - a page HelpLinks.swift links to (page("…")) wasn't built
#   - the vendored openapi.yaml wasn't published at api/openapi.yaml
#   - an internal link in the built site points at a page that doesn't exist

require "json"
require "set"

ROOT = File.expand_path("..", __dir__)
site = File.expand_path(ARGV[0] || File.join(ROOT, "help", "_site"))
abort "help-check: #{site} doesn't exist; build the site first" unless File.directory?(site)
baseurl = "/substratalapps-macos"
problems = []

catalog = JSON.parse(File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Resources/screens.json")))
catalog.fetch("screens").each do |screen|
  page = File.join(site, "screens", screen["id"].downcase, "index.html")
  problems << "no help page for #{screen['id']} (expected screens/#{screen['id'].downcase}/)" unless File.exist?(page)
end

help_links = File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Help/HelpLinks.swift"))
help_links.scan(/page\("([^"\\]+)"\)/).flatten.each do |path|
  problems << "HelpLinks.swift links to #{path}, which wasn't built" unless File.exist?(File.join(site, path, "index.html"))
end

problems << "api/openapi.yaml wasn't published" unless File.exist?(File.join(site, "api", "openapi.yaml"))

# Internal links, skipping archived snapshots (each was checked when it was built).
pages = Dir.glob(File.join(site, "**", "*.html")).reject { |f| f.include?("/versions/") && !f.end_with?("versions/index.html") }
checked = Set.new
pages.each do |file|
  File.read(file).scan(/href="(#{Regexp.escape(baseurl)}\/[^"#?]*)/).flatten.each do |href|
    next if href.include?("/versions/") || checked.include?(href)

    checked << href
    rel = href.delete_prefix(baseurl)
    target = File.join(site, rel)
    ok = File.file?(target) || File.exist?(File.join(target, "index.html"))
    problems << "broken link #{href} (in #{file.delete_prefix(site)})" unless ok
  end
end

if problems.empty?
  puts "help-check: ok (#{catalog['screens'].size} screens, #{checked.size} internal links)"
else
  warn problems.uniq.map { |p| "help-check: #{p}" }
  exit 1
end
