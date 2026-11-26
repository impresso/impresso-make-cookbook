# One JSON object per media-agency mention (flattens .entities of each content item).
# Input:  {"id": "LSE-1933-01-03-a-i0026", "entities": [{"label", "offset": [start, end], "wikidata_id"}]}
# Output: {"ci_id", "newspaper", "date", "label", "wikidata_id", "start", "end"}
.id as $ci
| (($ci | first(capture("^(?<newspaper>.+)-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})-"))) // {}) as $m
| (.entities // [])[]
| {
    ci_id: $ci,
    newspaper: $m.newspaper,
    date: $m.date,
    label: .label,
    wikidata_id: .wikidata_id,
    start: .offset[0],
    end: .offset[1]
  }
