#!/usr/bin/env ruby

require "yaml"

ROOT = File.expand_path("..", __dir__)

def fail_contract(message)
  warn "workflow contract failed: #{message}"
  exit 1
end

def load_workflow(path)
  YAML.safe_load(File.read(path), aliases: true)
rescue Errno::ENOENT
  fail_contract("missing #{path.delete_prefix("#{ROOT}/")}")
rescue Psych::SyntaxError => error
  fail_contract("#{path.delete_prefix("#{ROOT}/")} is invalid YAML: #{error.message}")
end

def triggers(workflow)
  workflow.fetch("on") { workflow.fetch(true) }
end

ci_path = File.join(ROOT, ".github/workflows/ci.yml")
release_path = File.join(ROOT, ".github/workflows/release.yml")
ci = load_workflow(ci_path)
release = load_workflow(release_path)

ci_triggers = triggers(ci)
fail_contract("CI push must be limited to main") unless ci_triggers.dig("push", "branches") == ["main"]
fail_contract("CI must run for pull requests") unless ci_triggers.key?("pull_request")

ci_text = File.read(ci_path)
fail_contract("daily CI must not package release assets") if ci_text.match?(/package-(release|windows)|upload-artifact/)

release_triggers = triggers(release)
fail_contract("Release must run only for v* tags") unless release_triggers == { "push" => { "tags" => ["v*"] } }

release_text = File.read(release_path)
validator_text = File.read(File.join(ROOT, "scripts/validate-release-ref.sh"))
required_release_fragments = [
  "permissions:\n  contents: read",
  "git merge-base --is-ancestor",
  "scripts/validate-release-ref.sh",
  'docs/releases/${GITHUB_REF_NAME}.md',
  "swift test",
  "scripts/package-release.sh",
  "scripts/package-windows.ps1",
  "scripts/test-windows-integration.ps1",
  "actions/upload-artifact@v7",
  "actions/download-artifact@v7",
  "RELEASE_METADATA.txt",
  "contents: write",
  "--notes",
  "--verify-tag",
  "--fail-on-no-commits",
  "gh release create"
]

required_release_fragments.each do |fragment|
  fail_contract("Release is missing #{fragment.inspect}") unless release_text.include?(fragment)
end

fail_contract("Release validator must require stable vX.Y.Z tags") unless validator_text.include?(
  "'^v[0-9]+\\.[0-9]+\\.[0-9]+$'"
)
fail_contract("Release validator must require versioned notes") unless validator_text.include?(
  'docs/releases/${TAG}.md'
)

puts "workflow contract passed"
