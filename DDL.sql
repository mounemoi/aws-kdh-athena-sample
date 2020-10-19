CREATE EXTERNAL TABLE test
(
 create_time TIMESTAMP,
 user_name VARCHAR(16),
 point INTEGER
)
PARTITIONED BY
(
 datehour STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION "s3://example-kdh-athena-20201013/test-table/"
TBLPROPERTIES
(
 "projection.enabled" = "true",
 "projection.datehour.type" = "date",
 "projection.datehour.range" = "2020/10/12/00,NOW",
 "projection.datehour.format" = "yyyy/MM/dd/HH",
 "projection.datehour.interval" = "1",
 "projection.datehour.interval.unit" = "HOURS",
 "storage.location.template" = "s3://example-kdh-athena-20201013/test-table/${datehour}"
)