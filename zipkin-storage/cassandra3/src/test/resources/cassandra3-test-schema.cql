CREATE KEYSPACE IF NOT EXISTS stress_zipkin3 WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'};

//-- same schema but remove all UDTs (as cassandra-stress doesn't support them)

CREATE TABLE IF NOT EXISTS stress_zipkin3.traces (
    trace_id            bigint,
    ts_uuid             timeuuid,
    id                  bigint,
    ts                  bigint,
    span_name           text,
    parent_id           bigint,
    duration            bigint,
    all_annotations     text, //-- can't do SASI on set<text>: comma-joined until CASSANDRA-11182
    PRIMARY KEY (trace_id, ts_uuid, id)
)
    WITH CLUSTERING ORDER BY (ts_uuid DESC)
    AND compaction = {'class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'}
    AND default_time_to_live =  604800;


CREATE TABLE IF NOT EXISTS stress_zipkin3.trace_by_service_span (
    service_name  text,             //-- service name
    span_name     text,             //-- span name, or blank for queries without span name
    bucket        int,              //-- time bucket, calculated as ts/interval (in microseconds), for some pre-configured interval like 1 day.
    ts            timeuuid,         //-- start timestamp of the span, truncated to millisecond precision
    trace_id      bigint,           //-- trace ID
    duration      bigint,           //-- span duration, in microseconds
    PRIMARY KEY ((service_name, span_name, bucket), ts)
)
   WITH CLUSTERING ORDER BY (ts DESC)
    AND compaction = {'class': 'org.apache.cassandra.db.compaction.TimeWindowCompactionStrategy'}
    AND default_time_to_live =  259200;

CREATE TABLE IF NOT EXISTS stress_zipkin3.span_name_by_service (
    service_name text,
    span_name    text,
    PRIMARY KEY (service_name, span_name)
)
    WITH compaction = {'class': 'org.apache.cassandra.db.compaction.LeveledCompactionStrategy', 'unchecked_tombstone_compaction': 'true', 'tombstone_threshold': '0.2'}
    AND default_time_to_live =  259200;

CREATE CUSTOM INDEX IF NOT EXISTS ON stress_zipkin3.traces (all_annotations) USING 'org.apache.cassandra.index.sasi.SASIIndex'
   WITH OPTIONS = {
    'mode': 'CONTAINS',
    'analyzed': 'true',
    'analyzer_class':'org.apache.cassandra.index.sasi.analyzer.NonTokenizingAnalyzer',
    'case_sensitive': 'false'
   };

CREATE CUSTOM INDEX IF NOT EXISTS ON stress_zipkin3.trace_by_service_span (duration) USING 'org.apache.cassandra.index.sasi.SASIIndex'
   WITH OPTIONS = {'mode': 'PREFIX'};


CREATE TABLE IF NOT EXISTS stress_zipkin3.dependencies (
    day          timestamp,
    links        blob,
    PRIMARY KEY (day)
)
    WITH compaction = {'class': 'org.apache.cassandra.db.compaction.LeveledCompactionStrategy', 'unchecked_tombstone_compaction': 'true', 'tombstone_threshold': '0.2'}
    AND default_time_to_live =  259200;
