#!/usr/bin/env ruby
# frozen_string_literal: true

# Imports the macOS screen inventory from the UI spec into the screen catalog
# that both the app and the help site read.
#
#   scripts/import-screens.rb [SPECS]
#
# SPECS is the published spec (default: https://specs.substratalapps.com/spec/)
# or a checkout of CompositeCode/substratal-hub-interface-specs. It reads
# macos/SCREENS.md and macos/README.md from the spec and writes
# Packages/SubstratalKit/Sources/SubstratalKit/Resources/screens.json.
#
# The spec is the source of truth for each screen's id, title, domain, route,
# archetype, phase, audience and purpose. The sidebar layout (which screens are
# sidebar destinations, their SF Symbols, shortcuts and visibility rules)
# comes from PLATFORM-SPEC.md §3 and INFORMATION-ARCHITECTURE.md §§2 and 5,
# and is kept in SIDEBAR below. Re-run this script whenever the spec changes,
# then commit the result: CI fails if the help site has no page for a screen.

require "json"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
specs = ARGV[0] || "https://specs.substratalapps.com/spec/"
# A spec file's text, from the published site or a checkout (specs/, or
# substratal-application-specs/ before spec 2.0.0).
read_spec = lambda do |rel|
  if specs.match?(%r{\Ahttps?://})
    res = Net::HTTP.get_response(URI.join(specs.end_with?("/") ? specs : "#{specs}/", rel))
    abort "import-screens: #{rel}: HTTP #{res.code} from #{specs}" unless res.is_a?(Net::HTTPSuccess)
    res.body.force_encoding("UTF-8")
  else
    dir = %w[specs substratal-application-specs].map { |d| File.join(File.expand_path(specs), d) }.find { |d| File.directory?(d) }
    abort "import-screens: #{specs} has no specs/ directory" unless dir
    File.read(File.join(dir, rel))
  end
end
source = "macos/SCREENS.md"
out = File.join(ROOT, "Packages", "SubstratalKit", "Sources", "SubstratalKit", "Resources", "screens.json")

# Sidebar destinations, in order. `visible_when` names a Capabilities rule
# (see Capabilities.swift); `shortcut` is the menu key equivalent.
SIDEBAR = {
  "APP-01" => { section: "personal", label: "Home", symbol: "square.grid.2x2", shortcut: "cmd+1", visible_when: "always" },
  "NTF-01" => { section: "personal", label: "Inbox", symbol: "tray", shortcut: "cmd+2", visible_when: "flag:notifications" },
  "ORG-01" => { section: "personal", label: "Organizations", symbol: "person.3", shortcut: "cmd+3", visible_when: "flag:organizations" },
  "ACC-01" => { section: "personal", label: "Account", symbol: "person.crop.circle", shortcut: "cmd+4", visible_when: "always" },
  "BIL-01" => { section: "personal", label: "Plan & Billing", symbol: "creditcard", shortcut: "cmd+5", visible_when: "flag:billing" },
  "SET-01" => { section: "personal", label: "Settings", symbol: "gearshape", shortcut: "cmd+6", visible_when: "always" },
  "USR-01" => { section: "administration", label: "Users", symbol: "person.2", shortcut: "opt+cmd+1", visible_when: "perm:users.list" },
  "ACX-05" => { section: "administration", label: "Access", symbol: "switch.2", shortcut: "opt+cmd+2", visible_when: "access" },
  "ROL-01" => { section: "administration", label: "Roles", symbol: "checkmark.shield", shortcut: "opt+cmd+3", visible_when: "perm:users.list" },
  "AUD-01" => { section: "administration", label: "Audit Log", symbol: "list.bullet.clipboard", shortcut: "opt+cmd+4", visible_when: "perm:audit.view" },
  "NTF-06" => { section: "administration", label: "Send notification", symbol: "bell.badge", shortcut: nil, visible_when: "perm:notifications.send" },
  "APL-01" => { section: "developer", label: "Applications", symbol: "shippingbox", shortcut: "ctrl+cmd+1", visible_when: "developer" },
  "KEY-01" => { section: "developer", label: "API Keys", symbol: "key", shortcut: "ctrl+cmd+2", visible_when: "developer" },
  "WHK-01" => { section: "developer", label: "Webhooks", symbol: "arrow.triangle.branch", shortcut: "ctrl+cmd+3", visible_when: "developer" },
  "BIL-04" => { section: "developer", label: "Tenant", symbol: "server.rack", shortcut: "ctrl+cmd+4", visible_when: "tenant" },
}.freeze

screens = []
lines = read_spec.call(source).lines(chomp: true)
lines.each_with_index do |line, i|
  next unless (m = line.match(/\A### ([A-Z]+-\d+) — (.+)\z/))

  meta = lines[i + 1].to_s
  who = lines[i + 2].to_s[/\*\*Who:\*\*\s*(.+?)\s*\z/, 1]
  purpose = lines[(i + 3)..(i + 6)].find { |l| l.start_with?("**Purpose:**") }.to_s.sub("**Purpose:**", "").strip
  field = ->(name) { meta[/\*\*#{name}:\*\*\s*([^·]+?)\s*(?:·|\z)/, 1]&.strip }
  domain = field.("Domain")
  screen = {
    id: m[1],
    title: m[2].strip,
    domain: domain,
    route: field.("Route")&.delete("`"),
    archetype: field.("Archetype"),
    phase: field.("Phase"),
    audience: who,
    purpose: purpose,
  }
  if (s = SIDEBAR[m[1]])
    screen[:sidebar] = s.merge(order: SIDEBAR.keys.index(m[1])).compact
  end
  screens << screen
end

abort "import-screens: no screens parsed from #{source}" if screens.empty?
missing = SIDEBAR.keys - screens.map { |s| s[:id] }
abort "import-screens: sidebar screens missing from the spec: #{missing.join(', ')}" unless missing.empty?

spec_version = read_spec.call("macos/README.md")[/\*\*API:\*\*\s*([^\n]+)/, 1]
doc = {
  "_generated" => "by scripts/import-screens.rb from the Hub specs' macos/SCREENS.md (https://specs.substratalapps.com/spec/); edit the spec, then re-run",
  "spec" => spec_version&.strip,
  "screens" => screens,
}
File.write(out, JSON.pretty_generate(doc) + "\n")
puts "import-screens: #{screens.size} screens (#{SIDEBAR.size} in the sidebar) → #{out.delete_prefix(ROOT + '/')}"
