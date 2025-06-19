
aggregate:
	python cookbook/lib/s3_aggregator.py --jq-filter cookbook/lib/langident_stats.jq \
	--s3-prefix s3://$(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT) \
	-o s3://$(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)__AGGREGATED.jsonl.gz 
