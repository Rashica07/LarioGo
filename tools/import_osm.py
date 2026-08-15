#!/usr/bin/env python3
"""Import real places around Lecco and Lake Como from OpenStreetMap.

Why OpenStreetMap and not Google Places:

    Google's Places API terms forbid warehousing place content. Only `place_id`
    may be stored indefinitely and coordinates for 30 days; names, ratings,
    reviews, photos and phone numbers must be fetched live and shown with
    Google attribution. "Call Place Details for every business and save the
    rows" is explicitly non-compliant, so it cannot back a database like ours.

    OpenStreetMap is ODbL. Commercial use is permitted, attribution is
    required, and derived databases are share-alike. That is compatible with
    what LarioGo does, and it is defensible in front of an institutional
    partner.

Attribution obligation this creates:
    The app MUST display "© OpenStreetMap contributors" wherever this data is
    shown. See AttributionView in the iOS app.

What this importer deliberately does NOT do:
    Invent ratings or review counts. Real ratings are proprietary to whoever
    collected them. LarioGo's ratings must come from LarioGo's own users, so
    imported places arrive unrated and the UI renders them as "New".

Usage:
    python tools/import_osm.py --out Backend/Resources/osm-places.json
    python tools/import_osm.py --area lecco --limit 200
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OVERPASS_ENDPOINT = "https://overpass-api.de/api/interpreter"

# South, West, North, East. Overpass wants this order.
AREAS = {
    # Tight box around the city and the Lecco branch — the MVP pilot area.
    "lecco": (45.80, 9.33, 45.92, 9.47),
    # The whole lake plus Como, for the expansion phase.
    "lakecomo": (45.78, 9.02, 46.18, 9.45),
}

# OSM tag -> (PlaceKind, PlaceCategory) used by LarioCore.
# Only tags that map cleanly are imported; anything else is skipped rather than
# guessed at, because a museum filed under "nightlife" is worse than absent.
TAG_MAP = {
    ("tourism", "attraction"): ("attraction", "landmark"),
    ("tourism", "museum"): ("attraction", "culture"),
    ("tourism", "viewpoint"): ("attraction", "viewpoint"),
    ("tourism", "artwork"): ("attraction", "culture"),
    ("tourism", "gallery"): ("attraction", "culture"),
    ("tourism", "picnic_site"): ("attraction", "nature"),
    ("historic", "castle"): ("attraction", "landmark"),
    ("historic", "monument"): ("attraction", "landmark"),
    ("historic", "memorial"): ("attraction", "culture"),
    ("historic", "ruins"): ("attraction", "landmark"),
    ("historic", "archaeological_site"): ("attraction", "culture"),
    ("historic", "church"): ("attraction", "culture"),
    ("amenity", "place_of_worship"): ("attraction", "culture"),
    ("amenity", "restaurant"): ("restaurant", "food"),
    ("amenity", "cafe"): ("restaurant", "food"),
    ("amenity", "bar"): ("restaurant", "nightlife"),
    ("amenity", "pub"): ("restaurant", "nightlife"),
    ("amenity", "ice_cream"): ("restaurant", "food"),
    ("amenity", "fast_food"): ("restaurant", "food"),
    ("leisure", "beach_resort"): ("attraction", "beach"),
    ("leisure", "nature_reserve"): ("attraction", "nature"),
    ("leisure", "park"): ("attraction", "nature"),
    ("natural", "beach"): ("attraction", "beach"),
    ("natural", "peak"): ("attraction", "viewpoint"),
    ("natural", "waterfall"): ("attraction", "nature"),
}

# OSM cuisine values -> display names. Unknown values pass through title-cased.
CUISINE_DISPLAY = {
    "italian": "Italian",
    "pizza": "Pizza",
    "regional": "Regional",
    "seafood": "Seafood",
    "fish": "Seafood",
    "ice_cream": "Gelato",
    "coffee_shop": "Café",
    "sandwich": "Sandwiches",
    "international": "International",
    "japanese": "Japanese",
    "chinese": "Chinese",
    "asian": "Asian",
    "mediterranean": "Mediterranean",
    "steak_house": "Steakhouse",
    "bakery": "Bakery",
}


def build_query(bbox: tuple[float, float, float, float]) -> str:
    """Overpass QL for every mapped tag inside the bounding box."""
    south, west, north, east = bbox
    box = f"({south},{west},{north},{east})"
    clauses = []
    seen_keys = set()
    for key, value in TAG_MAP:
        clauses.append(f'  nwr["{key}"="{value}"]{box};')
        seen_keys.add(key)
    body = "\n".join(clauses)
    # `out center` gives a representative point for ways/relations, so a museum
    # mapped as a building still yields usable coordinates.
    return f"[out:json][timeout:120];\n(\n{body}\n);\nout center tags;"


def fetch(query: str, retries: int = 3) -> dict:
    data = urllib.parse.urlencode({"data": query}).encode()
    request = urllib.request.Request(
        OVERPASS_ENDPOINT,
        data=data,
        headers={
            # Overpass asks for a descriptive agent so they can contact abusers
            # rather than blanket-ban. Being a good citizen here is not optional.
            "User-Agent": "LarioGo/0.1 (tourism app; Lecco, Italy; contact via repository)",
        },
    )
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            # 429/504 mean the public instance is busy; back off rather than hammer.
            if exc.code in (429, 504) and attempt < retries:
                wait = 10 * attempt
                print(f"  Overpass returned {exc.code}; waiting {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            raise
        except urllib.error.URLError as exc:
            if attempt < retries:
                time.sleep(5 * attempt)
                continue
            raise RuntimeError(f"Could not reach Overpass: {exc}") from exc
    raise RuntimeError("Overpass request failed after retries")


def classify(tags: dict) -> tuple[str, str] | None:
    for (key, value), mapped in TAG_MAP.items():
        if tags.get(key) == value:
            return mapped
    return None


def coordinates(element: dict) -> tuple[float, float] | None:
    if "lat" in element and "lon" in element:
        return element["lat"], element["lon"]
    centre = element.get("center")
    if centre:
        return centre["lat"], centre["lon"]
    return None


def address(tags: dict) -> str | None:
    street = tags.get("addr:street")
    number = tags.get("addr:housenumber")
    city = tags.get("addr:city")
    parts = []
    if street:
        parts.append(f"{street} {number}" if number else street)
    if city:
        parts.append(city)
    return ", ".join(parts) if parts else None


def cuisines(tags: dict) -> list[str]:
    raw = tags.get("cuisine", "")
    out = []
    for item in raw.split(";"):
        item = item.strip().lower()
        if not item:
            continue
        out.append(CUISINE_DISPLAY.get(item, item.replace("_", " ").title()))
    return out


# Names that are mapped as parks or viewpoints but are not tourist destinations.
# leisure=park in particular catches municipal dog runs and verges.
EXCLUDED_NAME_FRAGMENTS = (
    "area cani", "area sgambamento", "parcheggio", "rotonda",
    "isola ecologica", "area verde di", "aiuola",
)


def is_tourist_relevant(name: str, category: str) -> bool:
    lowered = name.casefold()
    return not any(fragment in lowered for fragment in EXCLUDED_NAME_FRAGMENTS)


def completeness(place: dict) -> int:
    """How much usable detail a place carries, 0-5.

    Not a quality judgement about the place — a real chapel with only a name is
    legitimate content. It lets the app rank complete entries first and lets us
    measure how much enrichment is still needed.
    """
    score = 0
    if place.get("about"):
        score += 1
    if place.get("website"):
        score += 1
    if place.get("phone"):
        score += 1
    if place.get("openingHours"):
        score += 1
    if place.get("wikidata"):
        score += 1
    return score


def convert(element: dict, region_hint: str) -> dict | None:
    tags = element.get("tags") or {}

    # A place with no name cannot be shown to a user or searched for.
    name = tags.get("name")
    if not name:
        return None

    mapped = classify(tags)
    if not mapped:
        return None
    kind, category = mapped

    position = coordinates(element)
    if not position:
        return None
    lat, lon = position

    # Prefer an Italian description, then English, then the generic one.
    description = (
        tags.get("description:it")
        or tags.get("description:en")
        or tags.get("description")
        or ""
    )

    if not is_tourist_relevant(name, category):
        return None

    return {
        "osmType": element.get("type"),
        "osmId": element.get("id"),
        "kind": kind,
        "category": category,
        "name": name,
        "tagline": "",
        "summary": description[:200],
        "about": description,
        "latitude": lat,
        "longitude": lon,
        "address": address(tags),
        "region": tags.get("addr:city") or region_hint,
        "imageNames": [],
        # Deliberately absent. Ratings must come from LarioGo's own users;
        # importing or inventing them would be dishonest and, if taken from a
        # commercial provider, a licensing violation.
        "rating": None,
        "reviewCount": 0,
        "priceLevel": None,
        "visitDuration": None,
        "website": tags.get("website") or tags.get("contact:website"),
        "phone": tags.get("phone") or tags.get("contact:phone"),
        "openingHours": tags.get("opening_hours"),
        "wheelchair": tags.get("wheelchair"),
        "cuisines": cuisines(tags),
        "acceptsReservations": tags.get("reservation") in ("yes", "required"),
        "tags": sorted({t for t in [
            tags.get("tourism"), tags.get("historic"), tags.get("amenity"),
            tags.get("leisure"), tags.get("natural"),
        ] if t}),
        "wikidata": tags.get("wikidata"),
        "wikipedia": tags.get("wikipedia"),
        "source": "openstreetmap",
        "attribution": "© OpenStreetMap contributors",
        "licence": "ODbL-1.0",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--area", choices=sorted(AREAS), default="lecco")
    parser.add_argument("--out", default="Backend/Resources/osm-places.json")
    parser.add_argument("--limit", type=int, default=0, help="0 means no limit")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    bbox = AREAS[args.area]
    query = build_query(bbox)
    print(f"Querying Overpass for '{args.area}' {bbox}...", file=sys.stderr)

    payload = fetch(query)
    elements = payload.get("elements", [])
    print(f"  {len(elements)} raw elements", file=sys.stderr)

    region_hint = "Lecco" if args.area == "lecco" else "Lake Como"
    south, west, north, east = bbox
    places, skipped, out_of_area = [], 0, 0
    seen = set()
    for element in elements:
        converted = convert(element, region_hint)
        if not converted:
            skipped += 1
            continue

        # Overpass returns relations that INTERSECT the box, so the centroid of
        # a large park or reserve can fall well outside it. Enforce the box on
        # the representative point, or the export contradicts its own metadata.
        if not (south <= converted["latitude"] <= north
                and west <= converted["longitude"] <= east):
            out_of_area += 1
            continue

        converted["completeness"] = completeness(converted)
        # The same feature can appear as both a node and a way.
        key = (converted["name"], round(converted["latitude"], 4), round(converted["longitude"], 4))
        if key in seen:
            continue
        seen.add(key)
        places.append(converted)

    places.sort(key=lambda p: (p["kind"], p["name"]))
    if args.limit:
        places = places[: args.limit]

    by_kind: dict[str, int] = {}
    for place in places:
        by_kind[place["kind"]] = by_kind.get(place["kind"], 0) + 1

    print(f"  kept {len(places)}, skipped {skipped} (unnamed/unmapped/not tourist-relevant), "
          f"{out_of_area} outside the box", file=sys.stderr)
    rich = sum(1 for p in places if p["completeness"] >= 2)
    print(f"    {rich} with two or more detail fields", file=sys.stderr)
    for kind, count in sorted(by_kind.items()):
        print(f"    {kind}: {count}", file=sys.stderr)

    document = {
        "source": "OpenStreetMap via Overpass API",
        "licence": "ODbL-1.0",
        "attribution": "© OpenStreetMap contributors",
        "area": args.area,
        "boundingBox": {"south": bbox[0], "west": bbox[1], "north": bbox[2], "east": bbox[3]},
        "count": len(places),
        "places": places,
    }

    if args.dry_run:
        print(json.dumps(document["places"][:3], indent=2, ensure_ascii=False))
        return 0

    import os
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(document, handle, indent=1, ensure_ascii=False)
    print(f"Wrote {len(places)} places to {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
