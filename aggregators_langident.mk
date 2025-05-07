
aggregate:
	python cookbook/lib/s3_aggregator.py --jq-filter lib/langident_stats.jq \
	--s3-prefix s3://$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT) \
	-o s3://$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT)__AGGREGATED.jsonl.gz 
