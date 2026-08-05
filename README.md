<h1 align="center">chroma</h1>

<p align="center">
  minimal chromium themes.
.</p>

<details open>
<summary><strong>overview</strong></summary>

`chroma` is a minimal Chromium theme builder driven by `themes.toml`.

<img width="640" height="418" alt="gruvbox" src="https://github.com/user-attachments/assets/ac1fe1f4-444c-42ee-a8d8-d8f5628b0c64" />
<img width="640" height="418" alt="black-metal" src="https://github.com/user-attachments/assets/2c1ff8fc-17e1-48db-81bf-65c82f1c6236" />
<img width="640" height="418" alt="iceberg-dark" src="https://github.com/user-attachments/assets/0ceba285-d78b-47ee-9052-2c1b5d837607" />

</details>

<details open>
<summary><strong>installation</strong></summary>

1. install [just](https://just.systems/) and [Nushell](https://www.nushell.sh/)
2. clone https://github.com/u-k-g/chroma
3. run `just build <theme> <optional accent color>` from the repository
4. open `chrome://extensions` or `chromium://extensions`
5. enable **developer mode**
6. select **load unpacked**
7. choose `dist/chroma`

</details>

<details>
<summary><strong>development</strong></summary>

- `just list` lists the available themes, their defaults and all accent colors
- `just build rose-pine` builds a theme with its default accent color
- `just build black-metal salmon` builds a specific theme and accent-color combination
- `just build black-metal 17` uses any hue from 0 to 359 as a custom accent color
- `just check` validates every theme and named accent-color combination
- `just clean` removes generated manifests

</details>
