#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the app's Help links against the shared Hub help center, so the app can
# never open a help page that doesn't exist. HELP is the published help center
# (the default) or a local build of it (CompositeCode/substratal-hub-interface-specs,
# `npm run build` → _site/help).
#
#   scripts/help-check.rb                 https://specs.substratalapps.com/help/
#   scripts/help-check.rb HELP            a URL, or a directory such as ../substratalapps-applications-specs/_site/help
#
# Fails when:
#   - a screen in this app's catalog has no page at screens/<id>.html
#   - a page HelpLinks.swift opens (page("…")) isn't in the build
#   - a #fragment HelpLinks.swift uses isn't an id on that page

require "json"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
help = ARGV[0] || "https://specs.substratalapps.com/help/"
REMOTE = help.match?(%r{\Ahttps?://})
if REMOTE
  help = help.end_with?("/") ? help : "#{help}/"
else
  help = File.expand_path(help)
  abort "help-check: #{help} doesn't exist; build the specs site first (npm ci && npm run build)" unless File.directory?(help)
end

# The page's HTML, or nil if it doesn't exist.
def page(base, path)
  return (File.exist?(File.join(base, path)) ? File.read(File.join(base, path)) : nil) unless REMOTE

  uri = URI.join(base, path)
  3.times do
    res = Net::HTTP.get_response(uri)
    return res.body.force_encoding("UTF-8") if res.is_a?(Net::HTTPSuccess)
    return nil unless res.is_a?(Net::HTTPRedirection)

    uri = URI.join(uri, res["location"])
  end
  nil
end
problems = []

catalog = JSON.parse(File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Resources/screens.json")))
catalog.fetch("screens").each do |screen|
  path = "screens/#{screen['id'].downcase}.html"
  problems << "no help page for #{screen['id']} (#{path})" unless page(help, path)
end

source = File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/Help/HelpLinks.swift"))
version = File.read(File.join(ROOT, "Packages/SubstratalKit/Sources/SubstratalKit/API/APIVersion.swift"))[/current: .*= \._(\d+)/, 1]
# screen(_:) builds screens/<id>.html per screen; the catalog loop above covers it.
links = source.scan(/page\("([^"]+)"(?:, fragment: "([^"]+)")?\)/).reject { |path, _| path.include?('\(id') }
abort "help-check: no page(...) links found in HelpLinks.swift" if links.empty?
links.each do |path, fragment|
  path = path.gsub('\(APIVersion.headerValue)', version.to_s)
  html = page(help, path)
  unless html
    problems << "HelpLinks.swift opens #{path}, which isn't in the help center"
    next
  end
  problems << "HelpLinks.swift opens #{path}##{fragment}, but that page has no id=\"#{fragment}\"" if fragment && !html.include?(%(id="#{fragment}"))
end

if problems.empty?
  puts "help-check: ok (#{catalog['screens'].size} screens, #{links.size} help links)"
else
  warn problems.map { |p| "help-check: #{p}" }
  exit 1
end
