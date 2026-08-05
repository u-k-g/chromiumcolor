#!/usr/bin/env nu

const EXPECTED_SLOTS = [
  blue
  purple
  pink
  red
  orange
  yellow
  green
  cyan
  grey
]

const REQUIRED_THEME_KEYS = [
  name
  description
  mode
  colors
]

const THEME_COLOR_KEYS = [
  frame
  frame_inactive
  bookmark_text
  button_background
  tab_background_text
  tab_background_text_inactive
  tab_text
  toolbar
  toolbar_button_icon
  toolbar_text
  frame_incognito
  frame_incognito_inactive
  tab_background_text_incognito
  tab_background_text_incognito_inactive
  omnibox_text
  omnibox_background
  ntp_background
  ntp_header
  ntp_link
  ntp_text
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

def lab-pivot [value: number] {
  let epsilon = (6.0 / 29.0) ** 3
  if $value > $epsilon {
    $value ** (1.0 / 3.0)
  } else {
    ($value / (3.0 * ((6.0 / 29.0) ** 2))) + (4.0 / 29.0)
  }
}

def rgb-to-lab [channels: list] {
  let linear = $channels | each {|channel| linearized-component $channel }
  let x = (($linear.0 * 0.4124564) + ($linear.1 * 0.3575761) + ($linear.2 * 0.1804375)) / 95.047
  let y = (($linear.0 * 0.2126729) + ($linear.1 * 0.7151522) + ($linear.2 * 0.0721750)) / 100.0
  let z = (($linear.0 * 0.0193339) + ($linear.1 * 0.1191920) + ($linear.2 * 0.9503041)) / 108.883
  let fx = lab-pivot $x
  let fy = lab-pivot $y
  let fz = lab-pivot $z
  [((116.0 * $fy) - 16.0) (500.0 * ($fx - $fy)) (200.0 * ($fy - $fz))]
}

def lab-distance [first: list, second: list] {
  0..2
  | each {|index|
      let delta = ($first | get $index) - ($second | get $index)
      $delta * $delta
    }
  | math sum
  | math sqrt
}

def validate-catalog [catalog: record] {
  let top_level = $catalog | columns
  for key in [project themes accent_colors] {
    if $key not-in $top_level {
      fail $"missing [($key)] table"
    }
  }

  let theme_ids = $catalog.themes | columns
  let accent_ids = $catalog.accent_colors | columns
  if ($theme_ids | is-empty) {
    fail "at least one [themes.<id>] table is required"
  }
  if ($accent_ids | is-empty) {
    fail "at least one [accent_colors.<id>] table is required"
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
    if (($theme.colors | describe) !~ '^record') {
      fail $"themes.($theme_id).colors must be a table"
    }
    let actual_color_keys = $theme.colors | columns | sort
    let expected_color_keys = $THEME_COLOR_KEYS | sort
    if $actual_color_keys != $expected_color_keys {
      fail $"themes.($theme_id).colors must contain every supported Chromium color exactly once"
    }
    for key in $THEME_COLOR_KEYS {
      let value = $theme.colors | get $key
      if (($value | describe) != "string") or ($value !~ '^#[0-9a-fA-F]{6}$') {
        fail $"themes.($theme_id).colors.($key) must be a #rrggbb color"
      }
    }
    if ($theme.colors.omnibox_text | str lowercase) != ($theme.colors.ntp_link | str lowercase) {
      fail $"themes.($theme_id) must use the same accent for colors.omnibox_text and colors.ntp_link"
    }
    if ('default_accent_color' in $keys) and ($theme.default_accent_color not-in $accent_ids) {
      fail $"themes.($theme_id).default_accent_color references an unknown accent color"
    }
    if properties in $keys {
      if (($theme.properties | describe) !~ '^record') {
        fail $"themes.($theme_id).properties must be a table"
      }
      let property_keys = $theme.properties | columns
      if not ($property_keys | all {|key| $key in [ntp_background_alignment ntp_logo_alternate] }) {
        fail $"themes.($theme_id).properties contains an unsupported Chromium property"
      }
      if ('ntp_logo_alternate' in $property_keys) and ($theme.properties.ntp_logo_alternate not-in [0 1]) {
        fail $"themes.($theme_id).properties.ntp_logo_alternate must be 0 or 1"
      }
      if ('ntp_background_alignment' in $property_keys) and (($theme.properties.ntp_background_alignment | describe) != "string") {
        fail $"themes.($theme_id).properties.ntp_background_alignment must be a string"
      }
    }
  }

  for accent_id in $accent_ids {
    if $accent_id !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' {
      fail $"invalid accent-color ID: ($accent_id)"
    }
    let accent = $catalog.accent_colors | get $accent_id
    let keys = $accent | columns
    for key in [name description slots hues] {
      if $key not-in $keys {
        fail $"accent_colors.($accent_id) is missing ($key)"
      }
    }
    for key in [name description] {
      let value = $accent | get $key
      if (($value | describe) != "string") or (($value | str trim | is-empty)) {
        fail $"accent_colors.($accent_id).($key) must be a non-empty string"
      }
    }
    if (($accent.slots | describe) !~ '^list') or ($accent.slots | is-empty) {
      fail $"accent_colors.($accent_id).slots must contain at least one Chromium tab-group slot"
    }
    if not ($accent.slots | all {|slot| $slot in $EXPECTED_SLOTS }) {
      fail $"accent_colors.($accent_id).slots contains an unknown Chromium tab-group slot"
    }
    if (($accent.slots | uniq | length) != ($accent.slots | length)) {
      fail $"accent_colors.($accent_id).slots must not contain duplicates"
    }
    if ('accent' not-in $keys) and ($accent.slots != $EXPECTED_SLOTS) {
      fail $"accent_colors.($accent_id).slots must contain Chromium's nine tab-group slots in order unless an explicit accent is provided"
    }
    if ('accent' in $keys) and ((($accent.accent | describe) != "string") or ($accent.accent !~ '^#[0-9a-fA-F]{6}$')) {
      fail $"accent_colors.($accent_id).accent must be a #rrggbb color"
    }
    if ('inherit_default' in $keys) and (($accent.inherit_default | describe) != "bool") {
      fail $"accent_colors.($accent_id).inherit_default must be a boolean"
    }
    if ('inherit_default' in $keys) and $accent.inherit_default and ('accent' not-in $keys) {
      fail $"accent_colors.($accent_id) must provide an explicit accent when inheriting a theme's default palette"
    }
    if (($accent.hues | describe) !~ '^list') or (($accent.hues | length) != ($accent.slots | length)) {
      fail $"accent_colors.($accent_id).hues must contain one integer for every slot"
    }
    if not ($accent.hues | all {|value|
      (($value | describe) == "int") and $value >= -1 and $value <= 359
    }) {
      fail $"accent_colors.($accent_id).hues must contain integers from -1 to 359"
    }
    if (($accent.hues | any {|value| $value == -1 })) and ('accent' not-in $keys) {
      fail $"accent_colors.($accent_id) must provide an explicit accent when using the neutral -1 hue"
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

def hues-around [middle: int] {
  0..8 | each {|index|
    (($middle - 28 + ($index * 7) + 360) mod 360)
  }
}

def resolve-accent [catalog: record, choice: string] {
  let accent_ids = $catalog.accent_colors | columns
  if $choice in $accent_ids {
    return ($catalog.accent_colors | get $choice)
  }
  if $choice =~ '^-?\d+$' {
    let middle = $choice | into int
    if $middle < 0 or $middle > 359 {
      fail $"accent hue must be an integer from 0 to 359; got '($choice)'"
    }
    return {
      name: $"Hue ($middle)°"
      description: $"A custom accent range centered at ($middle) degrees."
      slots: $EXPECTED_SLOTS
      hues: (hues-around $middle)
    }
  }
  fail $"unknown accent color or hue '($choice)'; choose a name from `just list` or an integer from 0 to 359"
}

def palette-accent-hex [palette: record] {
  if 'accent' in ($palette | columns) {
    $palette.accent | str uppercase
  } else {
    hct-to-hex $palette.hues.4
  }
}

def closest-accent-id [catalog: record, theme: record] {
  let accent = rgb-to-lab (rgb $theme.colors.omnibox_text)
  $catalog.accent_colors
  | transpose id palette
  | where {|entry| 'accent' not-in ($entry.palette | columns) }
  | each {|entry|
      let midpoint = palette-accent-hex $entry.palette
      {
        id: $entry.id
        distance: (lab-distance $accent (rgb-to-lab (rgb $midpoint)))
      }
    }
  | sort-by distance
  | first
  | get id
}

def default-accent-id [catalog: record, theme: record] {
  if 'default_accent_color' in ($theme | columns) {
    $theme.default_accent_color
  } else {
    closest-accent-id $catalog $theme
  }
}

def tab-group-overrides [catalog: record, theme: record, palette: record] {
  let selected = $palette.slots
    | zip $palette.hues
    | reduce -f {} {|pair, overrides|
        $overrides | insert $"($pair.0)_override" $pair.1
      }
  if ('inherit_default' not-in ($palette | columns)) or (not $palette.inherit_default) {
    return $selected
  }

  let default_id = default-accent-id $catalog $theme
  let candidate = $catalog.accent_colors | get $default_id
  let base = if ('inherit_default' in ($candidate | columns)) and $candidate.inherit_default {
    $catalog.accent_colors | get (closest-accent-id $catalog $theme)
  } else {
    $candidate
  }
  let inherited = $base.slots
    | zip $base.hues
    | reduce -f {} {|pair, overrides|
        $overrides | insert $"($pair.0)_override" $pair.1
      }
  $inherited | merge $selected
}

def make-manifest [catalog: record, theme_id: string, accent_choice: string] {
  let theme_ids = $catalog.themes | columns
  if $theme_id not-in $theme_ids {
    fail $"unknown theme '($theme_id)'; choose one of: ($theme_ids | str join ', ')"
  }

  let theme = $catalog.themes | get $theme_id
  let palette = resolve-accent $catalog $accent_choice
  let tab_group_palette = tab-group-overrides $catalog $theme $palette

  let accent_rgb = rgb (palette-accent-hex $palette)
  let colors = $theme.colors
    | transpose key value
    | reduce -f {} {|entry, generated|
        $generated | insert $entry.key (rgb $entry.value)
      }
    | upsert omnibox_text $accent_rgb
    | upsert ntp_link $accent_rgb

  mut properties = {
    ntp_logo_alternate: (if $theme.mode == dark { 1 } else { 0 })
  }
  if properties in ($theme | columns) {
    $properties = $properties | merge $theme.properties
  }

  let generated_theme = {
    colors: $colors
    tab_group_color_palette: $tab_group_palette
    tints: {
      buttons: [-1 -1 -1]
      frame: [-1 -1 -1]
      frame_inactive: [-1 -1 -1]
      frame_incognito: [-1 -1 -1]
      frame_incognito_inactive: [-1 -1 -1]
    }
    properties: $properties
  }
  {
    version: $catalog.project.version
    name: $"($catalog.project.name) — ($theme.name) / ($palette.name)"
    description: $"($theme.description) ($palette.name) colors apply to tab groups and accents."
    manifest_version: 3
    theme: $generated_theme
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
  let allowed_slots = $EXPECTED_SLOTS | each {|slot| $"($slot)_override" }
  if ($actual_slots | is-empty) or (not ($actual_slots | all {|slot| $slot in $allowed_slots })) {
    fail "generated tab-group palette has invalid slots"
  }
  for hue in ($manifest.theme.tab_group_color_palette | values) {
    if (($hue | describe) != "int") or ($hue < -1) or ($hue > 359) {
      fail "generated tab-group palette has an invalid hue"
    }
  }
}

def print-catalog [catalog: record] {
  print "Themes:"
  for theme_id in ($catalog.themes | columns) {
    let theme = $catalog.themes | get $theme_id
    let padded_id = $theme_id | fill --alignment left --width 14
    let default_accent = default-accent-id $catalog $theme
    print $"  ($padded_id) default: ($default_accent)"
  }
  print "\nAccent colors:"
  for accent_id in ($catalog.accent_colors | columns) {
    let accent = $catalog.accent_colors | get $accent_id
    let padded_id = $accent_id | fill --alignment left --width 14
    let middle_color = palette-accent-hex $accent
    let color = ansi $middle_color
    let reset = ansi reset
    let detail = if 'accent' in ($accent | columns) { "neutral" } else { $"($accent.hues.4)°" }
    print $"($color)  ($padded_id) ~ ($middle_color) \(($detail)\)($reset)"
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
    fail "usage: just build [theme] [accent-color|hue]"
  }
  if ([$list $check $clean] | where {|action| $action } | length) > 1 {
    fail "choose only one of --list, --check or --clean"
  }
  if (($list or $check or $clean) and (not ($selection | is-empty))) {
    fail "catalog actions do not accept theme or accent-color choices"
  }

  let root = $env.CURRENT_FILE | path dirname | path dirname | path expand
  let catalog_path = $root | path join themes.toml
  let dist = $root | path join dist
  let default_output = $dist | path join chroma

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
    let accent_ids = $catalog.accent_colors | columns
    for theme_id in ($catalog.themes | columns) {
      let theme = $catalog.themes | get $theme_id
      let baseline_manifest = make-manifest $catalog $theme_id $accent_ids.0
      let baseline = $baseline_manifest.theme
        | update colors ($baseline_manifest.theme.colors | reject omnibox_text ntp_link)
        | reject tab_group_color_palette
      for accent_id in $accent_ids {
        let manifest = make-manifest $catalog $theme_id $accent_id
        validate-manifest $manifest
        let generated_theme = $manifest.theme
          | update colors ($manifest.theme.colors | reject omnibox_text ntp_link)
          | reject tab_group_color_palette
        if $generated_theme != $baseline {
          fail $"accent color '($accent_id)' changes non-accent browser colors for theme '($theme_id)'"
        }
        let accent = $catalog.accent_colors | get $accent_id
        let expected_accent = rgb (palette-accent-hex $accent)
        if ($manifest.theme.colors.omnibox_text != $expected_accent) or ($manifest.theme.colors.ntp_link != $expected_accent) {
          fail $"accent color '($accent_id)' does not set both accent colors for theme '($theme_id)'"
        }
        let expected_palette = tab-group-overrides $catalog $theme $accent
        if $manifest.theme.tab_group_color_palette != $expected_palette {
          fail $"accent color '($accent_id)' does not set the expected tab-group overrides for theme '($theme_id)'"
        }
        $combinations = $combinations + 1
      }

      let default_palette = make-manifest $catalog $theme_id (default-accent-id $catalog $theme)
      let grey_palette = make-manifest $catalog $theme_id grey
      for slot in ($EXPECTED_SLOTS | where {|slot| $slot != grey }) {
        let key = $"($slot)_override"
        if ($grey_palette.theme.tab_group_color_palette | get $key) != ($default_palette.theme.tab_group_color_palette | get $key) {
          fail $"grey accent does not preserve the default ($slot) tab-group color for theme '($theme_id)'"
        }
      }
      if $grey_palette.theme.tab_group_color_palette.grey_override != -1 {
        fail $"grey accent does not set the neutral tab-group color for theme '($theme_id)'"
      }
    }
    for middle in [0 17 359] {
      let manifest = make-manifest $catalog $catalog.project.default_theme ($middle | into string)
      validate-manifest $manifest
      let actual_hues = $manifest.theme.tab_group_color_palette | values
      let expected_hues = hues-around $middle
      if $actual_hues != $expected_hues {
        fail $"custom accent hue ($middle) did not generate the expected 7-degree range"
      }
      let expected_accent = rgb (hct-to-hex $middle)
      if ($manifest.theme.colors.omnibox_text != $expected_accent) or ($manifest.theme.colors.ntp_link != $expected_accent) {
        fail $"custom accent hue ($middle) did not set both accent colors"
      }
    }
    print $"Validated ($combinations) named combinations and custom hue generation."
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
  let accent_id = if ($selection | length) == 2 {
    $selection.1
  } else {
    default-accent-id $catalog $theme
  }
  let manifest = make-manifest $catalog $theme_id $accent_id
  validate-manifest $manifest
  let destination = write-manifest $manifest $default_output
  print $"Built ($theme_id) + ($accent_id): ($destination | path relative-to $root)"
  print $"Load unpacked: ($default_output)"
}
