set shell := ["bash", "-euo", "pipefail", "-c"]

# List available recipes.
default:
  @echo 'Available recipes:'
  @echo '    build [theme] [folder-color]  # Build one load-unpacked theme in dist/chromiumcolor/.'
  @echo '    check                         # Validate every theme/folder-color combination.'
  @echo '    clean                         # Remove generated manifests.'
  @echo '    list                          # List themes and folder colors.'

# Build one load-unpacked theme in dist/chromiumcolor/.
build *selection:
  python3 scripts/build_theme.py {{selection}}

# List theme and folder-color IDs from themes.toml.
list:
  @python3 scripts/build_theme.py --list

# Validate themes.toml and exercise every combination without writing output.
check:
  python3 scripts/build_theme.py --check

# Remove generated manifests.
clean:
  python3 scripts/build_theme.py --clean
