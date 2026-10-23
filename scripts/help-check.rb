#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the app's Help links against a build of the shared Hub help center
# (CompositeCode/substratalapps-applications-specs, `npm run build` → _site/help),
# so the app can never open a help page that doesn't exist.
#
#   scripts/help-check.rb HELP_DIR        e.g. ../substratalapps-applications-specs/_site/help
#
# Fails when:
#   - a screen in this app's catalog has no page at screens/<id>.html
#   - a page HelpLinks.swift opens (page("…")) isn't in the build
#   - a #fragment HelpLinks.swift uses isn't an id on that page

require "json"

ROOT = File.expand_path("..", __dir__)
help = File.expand_path(ARGV[0] || File.join(ROOT, "..", "substratalapps-applications-specs", "_site", "help"))
abort "help-check: #{help} doesn't exist; build the specs site first (npm ci && npm run build)" unless File.directory?(help)
problems = []

catalog = JSON.parse(File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Resources/screens.json")))
catalog.fetch("screens").each do |screen|
  page = File.join(help, "screens", "#{screen['id'].downcase}.html")
  problems << "no help page for #{screen['id']} (screens/#{screen['id'].downcase}.html)" unless File.exist?(page)
end

source = File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Help/HelpLinks.swift"))
version = File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/API/APIVersion.swift"))[/current: .*= \._(\d+)/, 1]
# screen(_:) builds screens/<id>.html per screen; the catalog loop above covers it.
links = source.scan(/page\("([^"]+)"(?:, fragment: "([^"]+)")?\)/).reject { |path, _| path.include?('\(id') }
abort "help-check: no page(...) links found in HelpLinks.swift" if links.empty?
links.each do |path, fragment|
  path = path.gsub('\(APIVersion.headerValue)', version.to_s)
  file = File.join(help, path)
  unless File.exist?(file)
    problems << "HelpLinks.swift opens #{path}, which isn't in the help center"
    next
  end
  problems << "HelpLinks.swift opens #{path}##{fragment}, but that page has no id=\"#{fragment}\"" if fragment && !File.read(file).include?(%(id="#{fragment}"))
end

if problems.empty?
  puts "help-check: ok (#{catalog['screens'].size} screens, #{links.size} help links)"
else
  warn problems.map { |p| "help-check: #{p}" }
  exit 1
end
