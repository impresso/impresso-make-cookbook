
aggregate:
	python cookbook/lib/s3_aggregator.py --jq-filter cookbook/lib/langident_stats.jq \
	--s3-prefix $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=) \
	-o $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.jsonl.gz 
