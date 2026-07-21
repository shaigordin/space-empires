# Datasets

## `assyrian_sites_starter.csv`

A starter set of 17 key Neo-Assyrian, Aramean/Luwian and Levantine sites for the
course project, ready to import into ArcGIS StoryMaps or Knight Lab StoryMap JS.

**Columns:** `name_en, ancient_name, modern_location, country, latitude,
longitude, category, pleiades_id, pleiades_uri, notes`

### Coordinate provenance (reproducible)

All coordinates are the **representative point** (`reprLat` / `reprLong`) of each
site's place record in the **[Pleiades](https://pleiades.stoa.org/) gazetteer of
ancient places** (CC-BY). Each row carries the Pleiades place id and URI, so any
value can be independently verified — open `pleiades_uri` and compare the
"Location" / representative point.

To regenerate or update the coordinates from scratch:

1. Download the official Pleiades places dump (updated daily):
   ```bash
   curl -sSL -o pleiades-places.csv.gz \
     https://atlantides.org/downloads/pleiades/dumps/pleiades-places-latest.csv.gz
   gunzip pleiades-places.csv.gz
   ```
2. For each site, take the row whose `id` matches `pleiades_id` in this file and
   read its `reprLat` (latitude) and `reprLong` (longitude). Values here are
   rounded to 5 decimal places.
3. Verify the chosen place is the intended settlement (not a sub-feature such as a
   palace, gate or cuneiform "Archive" record) by checking the `title` and that
   the point falls at the expected location.

A note on look-ups: several ancient toponyms map to a modern Arabic name that
recurs elsewhere (e.g. Til Barsip on the Euphrates is Pleiades **Bersiba**
[658410], *not* the unrelated "Tell Ahmar" [874725] far to the east). Always
confirm by coordinates, not name alone.

### Enrich further

- Pleiades — https://pleiades.stoa.org/ (download places as CSV/GeoJSON)
- MAPA, Mesopotamian Ancient Place-names Almanac — https://doi.org/10.5281/zenodo.6411251
- CIGS, Cuneiform Inscriptions Geographical Site Index — https://github.com/glow-gh/cigs
