
aggregate:
	python cookbook/lib/s3_aggregator.py --jq-filter cookbook/lib/langident_stats.jq \
	--s3-prefix $(S3_PATH_LANGIDENT) \
	-o $(S3_PATH_LANGIDENT)__AGGREGATED.jsonl.gz 
