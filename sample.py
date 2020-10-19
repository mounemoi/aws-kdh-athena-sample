import random
import json
import time
import datetime
import boto3

LOG_COUNT = 600

# 手順1 で作成を行った Kineis Data Firehose のストリーム名に変更します
KDH_STREAM_NAME = 'sample-kdh-athena'

client = boto3.client('firehose')


def lambda_handler(event, context):
    for dummy in range(LOG_COUNT):
        put_kdh({
            "create_time": datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "user_name": random.choice(['user01', 'user02', 'user03', 'user04']),
            "point": random.randint(0, 100),
        })
        time.sleep(1)


def put_kdh(log):
    return client.put_record(
        DeliveryStreamName=KDH_STREAM_NAME,
        Record={'Data': "{}\n".format(json.dumps(log))},
    )
