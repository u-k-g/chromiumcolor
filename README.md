# chromiumcolor

<details open>
<summary><strong>overview</strong></summary>

`chromiumcolor` is a minimal chromium theme builder driven by `themes.toml`. choose a browser theme, pair it with a tab-group color palette and compile a directory ready to load unpacked.

- multiple dark and light browser themes
- independent folder colors that affect tab groups only
- one generated theme in `dist/chromiumcolor`

<img width="1600" height="1045" alt="chromiumcolor" src="https://github.com/user-attachments/assets/ac1fe1f4-444c-42ee-a8d8-d8f5628b0c64" />

</details>

<details open>
<summary><strong>setup and build</strong></summary>

install [just](https://just.systems/) and [nushell](https://www.nushell.sh/), then:

```sh
git clone https://github.com/u-k-g/chromiumcolor.git
cd chromiumcolor

# show the available themes, their defaults and all folder colors
just list

# build the default theme and folder color
just build

# build a theme with its default folder color
just build rose-pine

# build a specific theme and folder-color combination
just build black-metal bathory
```

`just build` writes the selected combination to `dist/chromiumcolor`. run it again and reload the unpacked theme whenever you want to switch combinations.

</details>

<details open>
<summary><strong>installation</strong></summary>

1. open `chrome://extensions` or `chromium://extensions`
2. enable **developer mode**
3. select **load unpacked**
4. choose `dist/chromiumcolor`

</details>
