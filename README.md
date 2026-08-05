# chroma

<details open>
<summary><strong>overview</strong></summary>

`chroma` is a minimal chromium theme builder driven by `themes.toml`. choose a browser theme, pair it with an accent color and compile a directory ready to load unpacked.

- multiple dark and light browser themes
- independent accent colors that keep tab groups and theme accents in sync
- one generated theme in `dist/chroma`

<img width="640" height="418" alt="gruvbox" src="https://github.com/user-attachments/assets/ac1fe1f4-444c-42ee-a8d8-d8f5628b0c64" />
<img width="640" height="418" alt="black-metal" src="https://github.com/user-attachments/assets/2c1ff8fc-17e1-48db-81bf-65c82f1c6236" />
<img width="640" height="418" alt="iceberg-dark" src="https://github.com/user-attachments/assets/0ceba285-d78b-47ee-9052-2c1b5d837607" />


</details>

<details open>
<summary><strong>setup, build, and installation</strong></summary>

clone chroma, then install [just](https://just.systems/) and [nushell](https://www.nushell.sh/), then:

```sh
# show the available themes, their defaults and all accent colors
just list

# build a theme with its default accent color
just build rose-pine

# build a specific theme and accent-color combination
just build black-metal salmon

# use any 0–359 hue as a custom accent color
just build black-metal 17
```

1. open `chrome://extensions` or `chromium://extensions`
2. enable **developer mode**
3. select **load unpacked**
4. choose `dist/chroma`

</details>
