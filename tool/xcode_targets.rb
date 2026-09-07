#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds (idempotently) the native companion targets to ios/Runner.xcodeproj:
#
#   OpenTransitLiveActivity        WidgetKit extension, ActivityKit, iOS 16.2+
#   opentransit Watch App          watchOS 10+ SwiftUI app
#   OpenTransitWatchComplications  WidgetKit extension inside the watch app
#
# Run it instead of editing the pbxproj by hand:
#
#   tool/xcode_targets.rb            # add or repair the targets
#   tool/xcode_targets.rb --check    # exit 1 if anything is missing
#
# It uses the `xcodeproj` gem that ships inside CocoaPods, so there is nothing
# extra to install; `tool/testflight.sh` calls it before archiving.

require 'xcodeproj'

ROOT       = File.expand_path('..', __dir__)
PROJECT    = File.join(ROOT, 'ios', 'Runner.xcodeproj')
APP_ID     = ENV.fetch('BUNDLE_ID', 'com.jeronimotech.opentransit')
TEAM_ID    = ENV['APPLE_TEAM_ID']
CHECK_ONLY = ARGV.include?('--check')

LIVE_ACTIVITY = {
  name: 'OpenTransitLiveActivity',
  dir: 'OpenTransitLiveActivity',
  bundle_id: "#{APP_ID}.LiveActivity",
  type: :app_extension,
  platform: :ios,
  deployment: '16.2',
  sources: ['OpenTransitLiveActivityBundle.swift', 'OpenTransitLiveActivity.swift', 'RouteBadge.swift'],
  shared: ['../Shared/OpenTransitActivityAttributes.swift']
}.freeze

WATCH_APP = {
  name: 'opentransit Watch App',
  dir: 'OpenTransitWatch',
  bundle_id: "#{APP_ID}.watchkitapp",
  type: :application,
  platform: :watchos,
  deployment: '10.0',
  sources: :all_swift,
  shared: []
}.freeze

WATCH_COMPLICATIONS = {
  name: 'OpenTransitWatchComplications',
  dir: 'OpenTransitWatchComplications',
  bundle_id: "#{APP_ID}.watchkitapp.complications",
  type: :app_extension,
  platform: :watchos,
  deployment: '10.0',
  sources: :all_swift,
  # The complication decodes the very board the watch app caches, so both
  # targets compile the one model file rather than keeping two copies in step.
  shared: ['../OpenTransitWatch/WatchModels.swift']
}.freeze

TARGETS = [LIVE_ACTIVITY, WATCH_APP, WATCH_COMPLICATIONS].freeze

def swift_files(spec)
  dir = File.join(ROOT, 'ios', spec[:dir])
  files = spec[:sources] == :all_swift ? Dir.glob(File.join(dir, '**', '*.swift')).sort : spec[:sources].map { |f| File.join(dir, f) }
  (files + spec[:shared].map { |f| File.expand_path(File.join(dir, f)) }).select { |f| File.exist?(f) }
end

project = Xcodeproj::Project.open(PROJECT)
missing = TARGETS.reject { |t| project.targets.any? { |x| x.name == t[:name] } }

if CHECK_ONLY
  if missing.empty?
    puts "ok: #{TARGETS.map { |t| t[:name] }.join(', ')}"
    exit 0
  end
  warn "missing targets: #{missing.map { |t| t[:name] }.join(', ')} — run tool/xcode_targets.rb"
  exit 1
end

app = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'
created = []

TARGETS.each do |spec|
  existing = project.targets.find { |t| t.name == spec[:name] }
  target = existing

  unless existing
    target = project.new_target(spec[:type], spec[:name], spec[:platform], spec[:deployment], nil, :swift)

    group = project.main_group.find_subpath(spec[:dir], true)
    group.set_source_tree('SOURCE_ROOT')
    swift_files(spec).each do |path|
      ref = group.new_reference(path)
      target.add_file_references([ref])
    end
  end

  plist = File.join('ios', spec[:dir], 'Info.plist')
  target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = spec[:bundle_id]
    s['PRODUCT_NAME'] = spec[:name]
    s['INFOPLIST_FILE'] = File.join(spec[:dir], 'Info.plist') if File.exist?(File.join(ROOT, plist))
    s['SWIFT_VERSION'] = '5.0'
    # Manual with nothing specified: `flutter build ios --no-codesign` runs
    # before the release script patches in the real profiles, and an Automatic
    # companion target fails that pass looking for a development profile it
    # will never have. testflight.sh fills these in for the archive.
    s['CODE_SIGN_STYLE'] = 'Manual'
    s['CODE_SIGN_IDENTITY'] = ''
    s['PROVISIONING_PROFILE_SPECIFIER'] = ''
    s['DEVELOPMENT_TEAM'] = TEAM_ID if TEAM_ID
    # Version has to come from Flutter, not from a self-reference: an empty
    # CFBundleShortVersionString makes the simulator reject the bundle with
    # "Invalid placeholder attributes" and the App Store reject the upload.
    s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    s['SKIP_INSTALL'] = 'YES'
    s['TARGETED_DEVICE_FAMILY'] = spec[:platform] == :watchos ? '4' : '1,2'
    if spec[:platform] == :watchos
      s['WATCHOS_DEPLOYMENT_TARGET'] = spec[:deployment]
      s['SDKROOT'] = 'watchos'
      s['SUPPORTED_PLATFORMS'] = 'watchsimulator watchos'
    else
      s['IPHONEOS_DEPLOYMENT_TARGET'] = spec[:deployment]
    end
  end

  # Point at Flutter/Generated.xcconfig directly, NOT at Runner's
  # Debug/Release.xcconfig: those also pull in the Pods xcconfig, and a watch
  # or widget target that inherits the app's framework search paths tries to
  # link MapLibre and fails. Generated.xcconfig only carries the build
  # name/number the version fields need.
  generated = project.files.find { |f| f.path.to_s.end_with?('Flutter/Generated.xcconfig') } ||
              project.main_group.find_subpath('Flutter', true).new_reference('Flutter/Generated.xcconfig')
  target.build_configurations.each { |config| config.base_configuration_reference ||= generated }

  created << spec[:name] unless existing
end

# Embed order matters: the watch app carries its complications, the phone app
# carries the watch app and the Live Activity extension.
def embed(project, host_name, child_name, phase_name, dst_subfolder)
  host = project.targets.find { |t| t.name == host_name }
  child = project.targets.find { |t| t.name == child_name }
  return unless host && child

  host.add_dependency(child) unless host.dependencies.any? { |d| d.target&.name == child_name }
  phase = host.copy_files_build_phases.find { |p| p.name == phase_name }
  phase ||= host.new_copy_files_build_phase(phase_name).tap do |p|
    p.symbol_dst_subfolder_spec = dst_subfolder
    p.dst_path = ''
  end
  return if phase.files_references.any? { |r| r.path.to_s.include?(child_name) }

  phase.add_file_reference(child.product_reference).tap do |f|
    f.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
end

# The app itself gained three Swift files that Flutter's template knows
# nothing about; attach any that are missing from the Runner target.
RUNNER_SOURCES = [
  'Runner/LiveActivityBridge.swift',
  'Runner/WatchSessionBridge.swift',
  'Shared/OpenTransitActivityAttributes.swift'
].freeze

runner_group = project.main_group
present = app.source_build_phase.files.map { |f| f.file_ref&.real_path&.to_s }.compact
RUNNER_SOURCES.each do |rel|
  abs = File.join(ROOT, 'ios', rel)
  next unless File.exist?(abs)
  next if present.any? { |x| x == abs }

  group_name = File.dirname(rel)
  group = group_name == '.' ? runner_group : runner_group.find_subpath(group_name, true)
  group.set_source_tree('SOURCE_ROOT') if group != runner_group
  ref = group.files.find { |f| f.real_path.to_s == abs } || group.new_reference(abs)
  app.add_file_references([ref])
end

embed(project, 'opentransit Watch App', 'OpenTransitWatchComplications', 'Embed Watch Complications', :plug_ins)
embed(project, 'Runner', 'opentransit Watch App', 'Embed Watch Content', :wrapper)
embed(project, 'Runner', 'OpenTransitLiveActivity', 'Embed App Extensions', :plug_ins)

# Flutter's "Thin Binary" script declares the whole app bundle as its output,
# so an embed phase scheduled after it produces "Cycle inside Runner". Both
# embed phases have to run before it.
def hoist_embed_phases(target, before_script:)
  idx = target.build_phases.index do |b|
    b.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && b.name == before_script
  end
  return unless idx

  %w[Embed Watch Content Embed App Extensions] # (documentation only)
  ['Embed Watch Content', 'Embed App Extensions'].each do |name|
    phase = target.build_phases.find { |b| b.respond_to?(:name) && b.name == name }
    next unless phase

    current = target.build_phases.index(phase)
    next if current < idx

    target.build_phases.delete_at(current)
    target.build_phases.insert(idx, phase)
    idx += 1
  end
end

hoist_embed_phases(app, before_script: 'Thin Binary')

# The watch app is a watch-only bundle; it needs the phone app's id to pair.
watch = project.targets.find { |t| t.name == 'opentransit Watch App' }
watch&.build_configurations&.each do |c|
  c.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = APP_ID
end

project.save
puts created.empty? ? 'targets already present' : "added: #{created.join(', ')}"
