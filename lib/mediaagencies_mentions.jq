# One JSON object per media-agency mention.
# Input, entities-nel.v2 (v1-1-0 and later):
#   {"ci_id", "ts", "model_id", "nes": [{"type", "fine_grained_type", "surface", "lOffset", "rOffset",
#     "confidence_ner", "wkdata_qid", "start_year", ...}]}
# Input, minimal format of the first v2.1.0 run (v1-0-0):
#   {"id", "entities": [{"label", "offset": [start, end], "wikidata_id"}]}
# Output: {"ci_id", "newspaper", "date", "type", "label", "wikidata_id", "start", "end",
#   "surface", "confidence_ner"}; the last two are null for the minimal format.
(.ci_id // .id) as $ci
| (($ci | first(capture("^(?<newspaper>.+)-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})-"))) // {}) as $m
| if has("nes") then
    .nes[]
    | {label: .fine_grained_type, type: .type, wikidata_id: .wkdata_qid,
       start: .lOffset, end: .rOffset, surface: .surface, confidence_ner: .confidence_ner}
  else
    (.entities // [])[]
    | {label: .label, type: (.label | split(".")[0:3] | join(".")), wikidata_id: .wikidata_id,
       start: .offset[0], end: .offset[1], surface: null, confidence_ner: null}
  end
| {ci_id: $ci, newspaper: $m.newspaper, date: $m.date, type, label, wikidata_id, start, end,
   surface, confidence_ner}
