def round_reals:
  walk(if type == "number" and . != floor then (. * 1000 | round) / 1000 else . end);

del(
  .ts,
  .model_id,
  .source_bucket,
  .source_key,
  .source_file,
  .source_path_segment,
  .provider,
  .newspaper,
  .nes[]?.type,
  .nes[]?.confidence_nel,
  .nes[]?.wkpedia_lg,
  .nes[]?.wkpedia_pagename,
  .nes[]?.start_year,
  .media_sources[]?.type,
  .media_sources[]?.confidence_nel,
  .media_sources[]?.wkpedia_lg,
  .media_sources[]?.wkpedia_pagename,
  .media_sources[]?.start_year
)
| if has("nes") then .nes = ([.nes[]? | select(.confidence_ner < 0.8)]) else . end
| if has("media_sources") then .media_sources = ([.media_sources[]? | select(.confidence_ner < 0.8)]) else . end
| select(((.nes // []) | length > 0) or ((.media_sources // []) | length > 0))
| round_reals
