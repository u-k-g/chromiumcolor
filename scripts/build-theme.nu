#!/usr/bin/env nu

const EXPECTED_SLOTS = [
  grey
  blue
  red
  yellow
  green
  pink
  purple
  cyan
  orange
]

const REQUIRED_THEME_KEYS = [
  name
  description
  mode
  frame
  toolbar
  foreground
  muted
  accent
  default_folder_color
]

def fail [message: string] {
  error make $message
}

def rgb [hex: string] {
  [1 3 5] | each {|start|
    $hex
    | str substring $start..($start + 1)
    | into int --radix 16
  }
}

def hex-hue [hex: string] {
  let channels = rgb $hex | each {|channel| $channel / 255.0 }
  let red = $channels.0
  let green = $channels.1
  let blue = $channels.2
  let maximum = $channels | math max
  let minimum = $channels | math min
  let delta = $maximum - $minimum

  if $delta == 0 {
    0
  } else {
    let sector = if $maximum == $red {
      (($green - $blue) / $delta) mod 6
    } else if $maximum == $green {
      (($blue - $red) / $delta) + 2
    } else {
      (($red - $green) / $delta) + 4
    }
    ((($sector * 60) + 360) mod 360) | math round | into int
  }
}

def validate-catalog [catalog: record] {
  let top_level = $catalog | columns
  for key in [project themes folder_colors] {
    if $key not-in $top_level {
      fail $"missing [($key)] table"
    }
  }

  let theme_ids = $catalog.themes | columns
  let folder_ids = $catalog.folder_colors | columns
  if ($theme_ids | is-empty) {
    fail "at least one [themes.<id>] table is required"
  }
  if ($folder_ids | is-empty) {
    fail "at least one [folder_colors.<id>] table is required"
  }

  for key in [name version default_theme] {
    if $key not-in ($catalog.project | columns) {
      fail $"project.($key) is required"
    }
    let value = $catalog.project | get $key
    if (($value | describe) != "string") or (($value | str trim | is-empty)) {
      fail $"project.($key) must be a non-empty string"
    }
  }
  if $catalog.project.version !~ '^\d+(?:\.\d+){0,3}$' {
    fail "project.version must contain one to four numeric components"
  }
  if $catalog.project.default_theme not-in $theme_ids {
    fail "project.default_theme does not reference a defined theme"
  }

  for theme_id in $theme_ids {
    if $theme_id !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' {
      fail $"invalid theme ID: ($theme_id)"
    }
    let theme = $catalog.themes | get $theme_id
    let keys = $theme | columns
    for key in $REQUIRED_THEME_KEYS {
      if $key not-in $keys {
        fail $"themes.($theme_id) is missing ($key)"
      }
    }
    if $theme.mode not-in [dark light] {
      fail $"themes.($theme_id).mode must be 'dark' or 'light'"
    }
    for key in [name description] {
      let value = $theme | get $key
      if (($value | describe) != "string") or (($value | str trim | is-empty)) {
        fail $"themes.($theme_id).($key) must be a non-empty string"
      }
    }
    for key in [frame toolbar foreground muted accent] {
      let value = $theme | get $key
      if (($value | describe) != "string") or ($value !~ '^#[0-9a-fA-F]{6}$') {
        fail $"themes.($theme_id).($key) must be a #rrggbb color"
      }
    }
    if $theme.default_folder_color not-in $folder_ids {
      fail $"themes.($theme_id).default_folder_color references an unknown palette"
    }
  }

  for folder_id in $folder_ids {
    if $folder_id !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' {
      fail $"invalid folder-color ID: ($folder_id)"
    }
    let folder = $catalog.folder_colors | get $folder_id
    let keys = $folder | columns
    for key in [name description base_color slots hues] {
      if $key not-in $keys {
        fail $"folder_colors.($folder_id) is missing ($key)"
      }
    }
    for key in [name description] {
      let value = $folder | get $key
      if (($value | describe) != "string") or (($value | str trim | is-empty)) {
        fail $"folder_colors.($folder_id).($key) must be a non-empty string"
      }
    }
    if (($folder.base_color | describe) != "string") or ($folder.base_color !~ '^#[0-9a-fA-F]{6}$') {
      fail $"folder_colors.($folder_id).base_color must be a #rrggbb color"
    }
    if $folder.slots != $EXPECTED_SLOTS {
      fail $"folder_colors.($folder_id).slots must contain Chromium's nine tab-group slots in order"
    }
    if (($folder.hues | describe) !~ '^list') or (($folder.hues | length) != 9) {
      fail $"folder_colors.($folder_id).hues must contain nine integers from 0 to 359"
    }
    if not ($folder.hues | all {|value|
      (($value | describe) == "int") and $value >= 0 and $value <= 359
    }) {
      fail $"folder_colors.($folder_id).hues must contain nine integers from 0 to 359"
    }

    let middle_hue = $folder.hues.4
    let base_hue = hex-hue $folder.base_color
    let difference = ($base_hue - $middle_hue) | math abs
    if ([$difference (360 - $difference)] | math min) > 6 {
      fail $"folder_colors.($folder_id).base_color has hue ($base_hue), which does not match middle hue ($middle_hue)"
    }
  }
}

def load-catalog [catalog_path: path] {
  let catalog = try {
    open $catalog_path
  } catch {|error|
    fail $"could not read themes.toml: ($error.msg)"
  }
  validate-catalog $catalog
  $catalog
}

def make-manifest [catalog: record, theme_id: string, folder_id: string] {
  let theme_ids = $catalog.themes | columns
  let folder_ids = $catalog.folder_colors | columns
  if $theme_id not-in $theme_ids {
    fail $"unknown theme '($theme_id)'; choose one of: ($theme_ids | str join ', ')"
  }
  if $folder_id not-in $folder_ids {
    fail $"unknown folder color '($folder_id)'; choose one of: ($folder_ids | str join ', ')"
  }

  let theme = $catalog.themes | get $theme_id
  let folder = $catalog.folder_colors | get $folder_id
  let frame = rgb $theme.frame
  let toolbar = rgb $theme.toolbar
  let foreground = rgb $theme.foreground
  let muted = rgb $theme.muted
  let accent = rgb $theme.accent
  let tab_group_palette = $folder.slots
    | zip $folder.hues
    | reduce -f {} {|pair, palette|
        $palette | insert $"($pair.0)_override" $pair.1
      }

  {
    version: $catalog.project.version
    name: $"($catalog.project.name) — ($theme.name) / ($folder.name)"
    description: $"($theme.description) ($folder.name) colors apply only to tab groups."
    manifest_version: 3
    theme: {
      colors: {
        frame: $frame
        frame_inactive: $frame
        bookmark_text: $foreground
        button_background: $frame
        tab_background_text: $muted
        tab_background_text_inactive: $muted
        tab_text: $foreground
        toolbar: $toolbar
        toolbar_button_icon: $foreground
        toolbar_text: $foreground
        frame_incognito: $frame
        frame_incognito_inactive: $frame
        tab_background_text_incognito: $foreground
        tab_background_text_incognito_inactive: $muted
        omnibox_text: $accent
        omnibox_background: $frame
        ntp_background: $frame
        ntp_header: $toolbar
        ntp_link: $accent
        ntp_text: $muted
      }
      tab_group_color_palette: $tab_group_palette
      tints: {
        buttons: [-1 -1 -1]
        frame: [-1 -1 -1]
        frame_inactive: [-1 -1 -1]
        frame_incognito: [-1 -1 -1]
        frame_incognito_inactive: [-1 -1 -1]
      }
      properties: {
        ntp_logo_alternate: (if $theme.mode == dark { 1 } else { 0 })
      }
    }
  }
}

def validate-manifest [manifest: record] {
  if $manifest.manifest_version != 3 {
    fail "generated manifest is not Manifest V3"
  }
  if ($manifest.name | str length) > 75 {
    fail "generated manifest name exceeds Chromium's 75-character limit"
  }
  if ($manifest.description | str length) > 132 {
    fail "generated manifest description exceeds Chromium's 132-character limit"
  }
  for entry in ($manifest.theme.colors | transpose key value) {
    if (($entry.value | describe) !~ '^list') or (($entry.value | length) != 3) {
      fail $"generated theme.colors.($entry.key) is not a valid RGB triplet"
    }
    if not ($entry.value | all {|channel|
      (($channel | describe) == "int") and $channel >= 0 and $channel <= 255
    }) {
      fail $"generated theme.colors.($entry.key) is not a valid RGB triplet"
    }
  }
  let actual_slots = $manifest.theme.tab_group_color_palette | columns | sort
  let expected_slots = $EXPECTED_SLOTS | each {|slot| $"($slot)_override" } | sort
  if $actual_slots != $expected_slots {
    fail "generated tab-group palette has the wrong slots"
  }
}

def print-catalog [catalog: record] {
  print "Themes:"
  for theme_id in ($catalog.themes | columns) {
    let theme = $catalog.themes | get $theme_id
    let padded_id = $theme_id | fill --alignment left --width 14
    print $"  ($padded_id) default: ($theme.default_folder_color)"
  }
  print "\nFolder colors (tab groups only):"
  for folder_id in ($catalog.folder_colors | columns) {
    let folder = $catalog.folder_colors | get $folder_id
    let padded_id = $folder_id | fill --alignment left --width 14
    print $"  ($padded_id) ~($folder.base_color) \(($folder.hues.4)°\)"
  }
}

def write-manifest [manifest: record, output_dir: path] {
  mkdir $output_dir
  let destination = $output_dir | path join manifest.json
  $manifest | to json --indent 2 | save --force $destination
  $destination
}

def main [
  ...selection: string
  --list
  --check
  --clean
] {
  if ($selection | length) > 2 {
    fail "usage: just build [theme] [folder-color]"
  }
  if ([$list $check $clean] | where {|action| $action } | length) > 1 {
    fail "choose only one of --list, --check or --clean"
  }
  if (($list or $check or $clean) and (not ($selection | is-empty))) {
    fail "catalog actions do not accept theme or folder-color choices"
  }

  let root = $env.CURRENT_FILE | path dirname | path dirname | path expand
  let catalog_path = $root | path join themes.toml
  let dist = $root | path join dist
  let default_output = $dist | path join chromiumcolor

  if $clean {
    if ($dist | path exists) {
      rm --recursive $dist
    }
    print "Removed dist/."
    return
  }

  let catalog = load-catalog $catalog_path
  if $list {
    print-catalog $catalog
    return
  }

  if $check {
    mut combinations = 0
    let folder_ids = $catalog.folder_colors | columns
    for theme_id in ($catalog.themes | columns) {
      let baseline_manifest = make-manifest $catalog $theme_id $folder_ids.0
      let baseline = $baseline_manifest.theme | reject tab_group_color_palette
      for folder_id in $folder_ids {
        let manifest = make-manifest $catalog $theme_id $folder_id
        validate-manifest $manifest
        let generated_theme = $manifest.theme | reject tab_group_color_palette
        if $generated_theme != $baseline {
          fail $"folder color '($folder_id)' changes non-tab-group values for theme '($theme_id)'"
        }
        $combinations = $combinations + 1
      }
    }
    print $"Validated ($combinations) theme/folder-color combinations."
    return
  }

  let theme_id = if ($selection | is-empty) {
    $catalog.project.default_theme
  } else {
    $selection.0
  }
  let theme_ids = $catalog.themes | columns
  if $theme_id not-in $theme_ids {
    fail $"unknown theme '($theme_id)'; choose one of: ($theme_ids | str join ', ')"
  }
  let theme = $catalog.themes | get $theme_id
  let folder_id = if ($selection | length) == 2 {
    $selection.1
  } else {
    $theme.default_folder_color
  }
  let manifest = make-manifest $catalog $theme_id $folder_id
  validate-manifest $manifest
  let destination = write-manifest $manifest $default_output
  print $"Built ($theme_id) + ($folder_id): ($destination | path relative-to $root)"
  print $"Load unpacked: ($default_output)"
}
