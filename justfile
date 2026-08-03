set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes.
default:
  @echo 'Available recipes:'
  @echo '    build [theme] [folder-color|hue]  # Build one load-unpacked theme in dist/chromiumcolor/.'
  @echo '    check                         # Validate every theme/folder-color combination.'
  @echo '    clean                         # Remove generated manifests.'
  @echo '    list                          # List themes and folder colors.'

# Build with a named folder color or a custom middle hue from 0 to 359.
build *selection:
  nu scripts/build-theme.nu {{selection}}

# List theme and named folder-color IDs from themes.toml.
list:
  @nu scripts/build-theme.nu --list

# Validate themes.toml and exercise every combination without writing output.
check:
  nu scripts/build-theme.nu --check

# Remove generated manifests.
clean:
  nu scripts/build-theme.nu --clean
