# Image list for the Biber Holz demo

`images.csv` lists every image the demo catalogue needs: **129 images** (8 top categories, 32 subcategories, 89 products). It was generated from the demo seed data (`Mercator.Seeds.BiberHolz`) on 2026-10-13. If the catalogue changes, regenerate it with `mix run priv/repo/image_list.exs` (after seeding) rather than editing it by hand.

## Columns

| Column | Meaning |
|---|---|
| `file` | Target file name, e.g. `products/BH-TD-LAE.webp` (article number) or `categories/bauholz.webp` (slug) |
| `type` | `category`, `subcategory` or `product` |
| `number_or_slug` | Article number or category slug; used to assign the image on import |
| `category` | German category name, for orientation |
| `name_de`, `name_en` | Name of the item |
| `image_prompt_en` | Item-specific part of the image prompt (English title, subtitle, description, wood species) |

## Style prompt (prefix for every item)

For a consistent look across all images, put this in front of each `image_prompt_en`:

> Photorealistic product photo for an Austrian timber company's web shop. Natural daylight, soft shadows, warm wood tones. Light, slightly blurred alpine background (meadow or mountain forest) or a neutral light wooden surface. The product in the centre, fully visible, no text, no logos, no people. Square format.

For **categories**, a slightly wider scene is better:

> Photorealistic scene for a category tile of an Austrian timber company's web shop, showing typical products of this category in an alpine setting. Natural daylight, warm wood tones, no text, no logos, no people. Square format.

## Technical requirements

- Square, at least **1024 × 1024 px**, JPEG, PNG or WebP. They are converted to WebP and scaled during import.
- File names as in the `file` column. The folder structure (`products/`, `categories/`) helps with the import, but isn't required.
- Images for individual variants (e.g. cutting board in stone pine / oak / walnut) are optional; without them the variants share the product image.
