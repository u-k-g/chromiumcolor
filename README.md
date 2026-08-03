# chromiumcolor

<details open>
<summary><strong>overview</strong></summary>

`chromiumcolor` is a minimal chromium theme builder driven by `themes.toml`. choose a browser theme, pair it with an accent color and compile a directory ready to load unpacked.

- multiple dark and light browser themes
- independent accent colors that keep tab groups and theme accents in sync
- one generated theme in `dist/chromiumcolor`

<img width="640" height="418" alt="gruvbox" src="https://github.com/user-attachments/assets/ac1fe1f4-444c-42ee-a8d8-d8f5628b0c64" />
<img width="640" height="418" alt="black-metal" src="https://github.com/user-attachments/assets/2c1ff8fc-17e1-48db-81bf-65c82f1c6236" />
<img width="640" height="418" alt="rose-pine" src="https://github.com/user-attachments/assets/9c782b12-dd17-45d1-999d-85405830c187" />
<img width="640" height="418" alt="iceberg-dark" src="https://github.com/user-attachments/assets/0ceba285-d78b-47ee-9052-2c1b5d837607" />


</details>

<details open>
<summary><strong>setup and build</strong></summary>

install [just](https://just.systems/) and [nushell](https://www.nushell.sh/), then:

```sh
git clone https://github.com/u-k-g/chromiumcolor.git
cd chromiumcolor

# show the available themes, their defaults and all accent colors
just list

# build the default theme and accent color
just build

# build a theme with its default accent color
just build rose-pine

# build a specific theme and accent-color combination
just build black-metal salmon

# use any 0–359 hue as a custom accent color
just build black-metal 17
```

The accent color can be a name from `just list` or an integer hue from `0` to `359`. A hue generates the other eight tab-group colors in 7-degree steps around it, and its middle color becomes the omnibox/new-tab-link accent. Themes can declare a curated default; otherwise the builder chooses the named midpoint closest to the authored accent. `just build` writes the selected combination to `dist/chromiumcolor`. run it again and reload the unpacked theme whenever you want to switch combinations.

</details>

<details open>
<summary><strong>installation</strong></summary>

1. open `chrome://extensions` or `chromium://extensions`
2. enable **developer mode**
3. select **load unpacked**
4. choose `dist/chromiumcolor`

</details>
