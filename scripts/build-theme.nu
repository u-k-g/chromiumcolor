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

# Chromium generates the tab-strip color shown on a dark frame as Material HCT shade 300.
# Source values: ui/color/dynamic_color/palette_factory.cc in Chromium.
#
# The HCT solver below is a Nushell port of Material Color Utilities' HCT solver:
# Copyright 2022 Google LLC, licensed under Apache-2.0.
# https://github.com/material-foundation/material-color-utilities
const PI = 3.141592653589793
const TAB_GROUP_CHROMA = 48.73
const TAB_GROUP_TONE = 76.14
const SCALED_DISCOUNT_FROM_LINRGB = [
  [0.001200833568784504 0.002389694492170889 0.0002795742885861124]
  [0.0005891086651375999 0.0029785502573438758 0.0003270666104008398]
  [0.00010146692491640572 0.0005364214359186694 0.0032979401770712076]
]
const LINRGB_FROM_SCALED_DISCOUNT = [
  [1373.2198709594231 -1100.4251190754821 -7.278681089101213]
  [-271.815969077903 559.6580465940733 -32.46047482791194]
  [1.9622899599665666 -57.173814538844006 308.7233197812385]
]
const Y_FROM_LINRGB = [0.2126 0.7152 0.0722]

def fail [message: string] {
  error make $message
}

def signum [value: number] {
  if $value < 0 { -1 } else if $value > 0 { 1 } else { 0 }
}

def atan2 [y: number, x: number] {
  if $x > 0 {
    ($y / $x) | math arctan
  } else if ($x < 0) and ($y >= 0) {
    (($y / $x) | math arctan) + $PI
  } else if ($x < 0) and ($y < 0) {
    (($y / $x) | math arctan) - $PI
  } else if ($x == 0) and ($y > 0) {
    $PI / 2
  } else if ($x == 0) and ($y < 0) {
    (0.0 - $PI) / 2.0
  } else {
    0.0
  }
}

def matrix-multiply [input: list, matrix: list] {
  $matrix | each {|row|
    ($input | zip $row | each {|pair| $pair.0 * $pair.1 } | math sum)
  }
}

def sanitize-radians [angle: number] {
  ($angle + ($PI * 8)) mod ($PI * 2)
}

def chromatic-adaptation [component: number] {
  let absolute = $component | math abs
  let powered = $absolute ** 0.42
  (signum $component) * 400.0 * $powered / ($powered + 27.13)
}

def hue-of [linrgb: list] {
  let discounted = matrix-multiply $linrgb $SCALED_DISCOUNT_FROM_LINRGB
  let red = chromatic-adaptation $discounted.0
  let green = chromatic-adaptation $discounted.1
  let blue = chromatic-adaptation $discounted.2
  let a = ((11.0 * $red) - (12.0 * $green) + $blue) / 11.0
  let b = ($red + $green - (2.0 * $blue)) / 9.0
  atan2 $b $a
}

def cyclic-order [a: number, b: number, c: number] {
  (sanitize-radians ($b - $a)) < (sanitize-radians ($c - $a))
}

def get-axis [vector: list, axis: int] {
  $vector | get $axis
}

def interpolate-point [source: list, amount: number, target: list] {
  $source | zip $target | each {|pair|
    $pair.0 + (($pair.1 - $pair.0) * $amount)
  }
}

def set-coordinate [source: list, coordinate: number, target: list, axis: int] {
  let source_axis = get-axis $source $axis
  let amount = ($coordinate - $source_axis) / ((get-axis $target $axis) - $source_axis)
  interpolate-point $source $amount $target
}

def bounded [value: number] {
  ($value >= 0.0) and ($value <= 100.0)
}

def nth-vertex [y: number, n: int] {
  let coordinate_a = if (($n mod 4) <= 1) { 0.0 } else { 100.0 }
  let coordinate_b = if (($n mod 2) == 0) { 0.0 } else { 100.0 }
  if $n < 4 {
    let green = $coordinate_a
    let blue = $coordinate_b
    let red = ($y - ($green * $Y_FROM_LINRGB.1) - ($blue * $Y_FROM_LINRGB.2)) / $Y_FROM_LINRGB.0
    if (bounded $red) { [$red $green $blue] } else { [-1.0 -1.0 -1.0] }
  } else if $n < 8 {
    let blue = $coordinate_a
    let red = $coordinate_b
    let green = ($y - ($red * $Y_FROM_LINRGB.0) - ($blue * $Y_FROM_LINRGB.2)) / $Y_FROM_LINRGB.1
    if (bounded $green) { [$red $green $blue] } else { [-1.0 -1.0 -1.0] }
  } else {
    let red = $coordinate_a
    let green = $coordinate_b
    let blue = ($y - ($red * $Y_FROM_LINRGB.0) - ($green * $Y_FROM_LINRGB.1)) / $Y_FROM_LINRGB.2
    if (bounded $blue) { [$red $green $blue] } else { [-1.0 -1.0 -1.0] }
  }
}

def bisect-to-segment [y: number, target_hue: number] {
  mut left = [-1.0 -1.0 -1.0]
  mut right = [-1.0 -1.0 -1.0]
  mut left_hue = 0.0
  mut right_hue = 0.0
  mut initialized = false
  mut uncut = true

  for n in 0..11 {
    let middle = nth-vertex $y $n
    if $middle.0 < 0 { continue }
    let middle_hue = hue-of $middle
    if not $initialized {
      $left = $middle
      $right = $middle
      $left_hue = $middle_hue
      $right_hue = $middle_hue
      $initialized = true
      continue
    }
    if $uncut or (cyclic-order $left_hue $middle_hue $right_hue) {
      $uncut = false
      if (cyclic-order $left_hue $target_hue $middle_hue) {
        $right = $middle
        $right_hue = $middle_hue
      } else {
        $left = $middle
        $left_hue = $middle_hue
      }
    }
  }
  [$left $right]
}

def true-delinearized [component: number] {
  let normalized = $component / 100.0
  let converted = if $normalized <= 0.0031308 {
    $normalized * 12.92
  } else {
    (1.055 * ($normalized ** (1.0 / 2.4))) - 0.055
  }
  $converted * 255.0
}

def linearized-component [component: number] {
  let normalized = $component / 255.0
  if $normalized <= 0.040449936 {
    $normalized / 12.92 * 100.0
  } else {
    (($normalized + 0.055) / 1.055) ** 2.4 * 100.0
  }
}

def bisect-to-limit [y: number, target_hue: number] {
  let segment = bisect-to-segment $y $target_hue
  mut left = $segment.0
  mut right = $segment.1
  mut left_hue = hue-of $left

  for axis in 0..2 {
    if (get-axis $left $axis) != (get-axis $right $axis) {
      mut left_plane = -1
      mut right_plane = 255
      if (get-axis $left $axis) < (get-axis $right $axis) {
        $left_plane = ((true-delinearized (get-axis $left $axis)) - 0.5) | math floor | into int
        $right_plane = ((true-delinearized (get-axis $right $axis)) - 0.5) | math ceil | into int
      } else {
        $left_plane = ((true-delinearized (get-axis $left $axis)) - 0.5) | math ceil | into int
        $right_plane = ((true-delinearized (get-axis $right $axis)) - 0.5) | math floor | into int
      }
      for _ in 0..7 {
        if (($right_plane - $left_plane) | math abs) <= 1 { break }
        let middle_plane = (($left_plane + $right_plane) / 2.0) | math floor | into int
        let coordinate = linearized-component ($middle_plane + 0.5)
        let middle = set-coordinate $left $coordinate $right $axis
        let middle_hue = hue-of $middle
        if (cyclic-order $left_hue $target_hue $middle_hue) {
          $right = $middle
          $right_plane = $middle_plane
        } else {
          $left = $middle
          $left_hue = $middle_hue
          $left_plane = $middle_plane
        }
      }
    }
  }
  $left | zip $right | each {|pair| ($pair.0 + $pair.1) / 2.0 }
}

def inverse-chromatic-adaptation [adapted: number] {
  let absolute = $adapted | math abs
  let base = [0.0 (27.13 * $absolute / (400.0 - $absolute))] | math max
  (signum $adapted) * ($base ** (1.0 / 0.42))
}

def y-from-lstar [lstar: number] {
  if $lstar > 8.0 {
    let root = ($lstar + 16.0) / 116.0
    $root * $root * $root * 100.0
  } else {
    $lstar / (24389.0 / 27.0) * 100.0
  }
}

def delinearized [component: number] {
  let rounded = (true-delinearized $component) | math round | into int
  if $rounded < 0 { 0 } else if $rounded > 255 { 255 } else { $rounded }
}

def rgb-to-hex [channels: list] {
  let encoded = $channels | each {|channel|
    $channel | format number --no-prefix | get upperhex | fill --character 0 --alignment right --width 2
  }
  $"#($encoded | str join)"
}

def linrgb-to-hex [linrgb: list] {
  let channels = $linrgb | each {|component| delinearized $component }
  rgb-to-hex $channels
}

def find-result-by-j [hue_radians: number, chroma: number, y: number] {
  mut j = ($y | math sqrt) * 11.0
  let background_ratio = 0.184186503
  let aw = 29.981000900
  let nbb = 1.016919255
  let ncb = 1.016919255
  let c = 0.689999998
  let z = 1.909169555
  let t_inner_coefficient = 1.0 / ((1.64 - (0.29 ** $background_ratio)) ** 0.73)
  let e_hue = 0.25 * (((($hue_radians + 2.0) | math cos)) + 3.8)
  let p1 = $e_hue * (50000.0 / 13.0) * $ncb
  let hue_sin = $hue_radians | math sin
  let hue_cos = $hue_radians | math cos

  for iteration in 0..4 {
    let j_normalized = $j / 100.0
    let alpha = if ($chroma == 0.0) or ($j == 0.0) { 0.0 } else { $chroma / ($j_normalized | math sqrt) }
    let t = ($alpha * $t_inner_coefficient) ** (1.0 / 0.9)
    let ac = $aw * ($j_normalized ** (1.0 / $c / $z))
    let p2 = $ac / $nbb
    let gamma = 23.0 * ($p2 + 0.305) * $t / ((23.0 * $p1) + (11.0 * $t * $hue_cos) + (108.0 * $t * $hue_sin))
    let a = $gamma * $hue_cos
    let b = $gamma * $hue_sin
    let red_adapted = ((460.0 * $p2) + (451.0 * $a) + (288.0 * $b)) / 1403.0
    let green_adapted = ((460.0 * $p2) - (891.0 * $a) - (261.0 * $b)) / 1403.0
    let blue_adapted = ((460.0 * $p2) - (220.0 * $a) - (6300.0 * $b)) / 1403.0
    let scaled = [
      (inverse-chromatic-adaptation $red_adapted)
      (inverse-chromatic-adaptation $green_adapted)
      (inverse-chromatic-adaptation $blue_adapted)
    ]
    let linrgb = matrix-multiply $scaled $LINRGB_FROM_SCALED_DISCOUNT
    if ($linrgb | any {|component| $component < 0 }) { return null }
    let fnj = ($linrgb | zip $Y_FROM_LINRGB | each {|pair| $pair.0 * $pair.1 } | math sum)
    if $fnj <= 0 { return null }
    if ($iteration == 4) or (((($fnj - $y) | math abs)) < 0.002) {
      if ($linrgb | any {|component| $component > 100.01 }) { return null }
      return (linrgb-to-hex $linrgb)
    }
    $j = $j - (($fnj - $y) * $j / (2.0 * $fnj))
  }
  null
}

def hct-to-hex [hue: number] {
  let sanitized_hue = if $hue < 0 { ($hue mod 360) + 360 } else { $hue mod 360 }
  let hue_radians = $sanitized_hue / 180.0 * $PI
  let y = y-from-lstar $TAB_GROUP_TONE
  let exact = find-result-by-j $hue_radians $TAB_GROUP_CHROMA $y
  if $exact != null {
    $exact
  } else {
    let linrgb = bisect-to-limit $y $hue_radians
    linrgb-to-hex $linrgb
  }
}

def rgb [hex: string] {
  [1 3 5] | each {|start|
    $hex
    | str substring $start..($start + 1)
    | into int --radix 16
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
    for key in [name description slots hues] {
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
  print "\nFolder colors (tab groups on dark themes):"
  for folder_id in ($catalog.folder_colors | columns) {
    let folder = $catalog.folder_colors | get $folder_id
    let padded_id = $folder_id | fill --alignment left --width 14
    let first_color = hct-to-hex $folder.hues.0
    let middle_color = hct-to-hex $folder.hues.4
    let last_color = hct-to-hex $folder.hues.8
    let color = ansi $middle_color
    let reset = ansi reset
    print $"($color)  ($padded_id) ~($first_color) - ($last_color) · middle ($middle_color) \(($folder.hues.4)°\)($reset)"
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
    if (hct-to-hex 40) != "#FFA683" {
      fail "HCT conversion does not match Chromium's shade-300 reference for hue 40"
    }
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
