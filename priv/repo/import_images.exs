# Imports the demo images from assets/img/ (categories/<slug>.*, products/<number>.*):
#
#     mix run priv/repo/import_images.exs [directory]
#
# Safe to repeat: images that were already imported are skipped.

dir = List.first(System.argv()) || "assets/img"
%{imported: imported, skipped: skipped, unknown: unknown} = Mercator.Seeds.Images.import(dir)

IO.puts("Imported #{imported} images, skipped #{skipped} already imported.")

if unknown != [] do
  IO.puts("No category or product found for:")
  Enum.each(unknown, &IO.puts("  #{&1}"))
end
