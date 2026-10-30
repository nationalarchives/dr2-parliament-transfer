from operator import itemgetter

import boto3
import os
import json
import io
import subprocess
from natsort import natsorted

s3_client = boto3.client("s3")
ctd_bucket = os.environ["CTD_BUCKET"]


def lambda_handler(event, context):
    print(event)
    for record in event["Records"]:
        s3_event = json.loads(record["body"])
        for s3_record in s3_event["Records"]:
            bucket = s3_record["s3"]["bucket"]["name"]
            key = s3_record["s3"]["object"]["key"]
            json_metadata = get_json_metadata(bucket, key)
            asset_id = json_metadata[0]['UUID']
            iaid = json_metadata[0]["IAID"]
            asset_source = json_metadata[0].get('digitalAssetSource', 'BornDigital').replace(" ", "")
            delete_replica_files(iaid)
            replica_files = []
            for metadata in json_metadata:
                series = metadata['Series']
                file_id = metadata['fileId']
                file_name = metadata['Filename']
                file_extension = metadata['Filename'].split(".")[-1]
                key = f"{asset_id}/{file_id}"
                if file_extension == "tif" or file_extension == "tiff":
                    jpg_bytes = convert_file(bucket, key)
                    s3_client.upload_fileobj(io.BytesIO(jpg_bytes), ctd_bucket, f"files/{iaid}/{file_id}.jpg")
                    file_extension = "jpg"
                    file_size = int(len(jpg_bytes) / 1000)
                else:
                    files_copy_source = {"Bucket": bucket, "Key": key}
                    s3_client.copy(files_copy_source, ctd_bucket, f"files/{iaid}/{file_id}.{file_extension}")
                    head_object_response = s3_client.head_object(Bucket=bucket, Key=key)
                    file_size = int(head_object_response['ContentLength'] / 1000)

                replica_files.append({
                    "checkSum": metadata['checksum_sha256'],
                    "format": file_extension,
                    "name": f"66/{series}/{file_id}.{file_extension}",
                    "originalName": file_name,
                    "size": file_size
                })

            sorted_replica_files = natsorted(replica_files, key=itemgetter(*['originalName']))
            replica_metadata = {
                'files': sorted_replica_files,
                'replicaId': asset_id,
                'origination': asset_source,
                'totalSize': sum([x['size'] for x in replica_files])
            }
            metadata_body = io.BytesIO(json.dumps(replica_metadata).encode("utf-8"))
            s3_client.upload_fileobj(metadata_body, ctd_bucket, f"metadata/{iaid}.json")


def delete_replica_files(iaid):
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=ctd_bucket, Prefix=f"files/{iaid}/"):
        objects = [{"Key": obj["Key"]} for obj in page.get("Contents", [])]
        if objects:
            response = s3_client.delete_objects(
                Bucket=ctd_bucket, Delete={"Objects": objects}
            )
            if response.get("Errors"):
                raise RuntimeError(f"Failed to delete replica files: {response['Errors']}")


def convert_file(bucket, key):
    tiff_obj = io.BytesIO()
    s3_client.download_fileobj(bucket, key, tiff_obj)
    tiff_obj.seek(0)

    process = subprocess.Popen(
        ["/opt/bin/convert", "tiff:-", "jpg:-"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    jpg_bytes, err = process.communicate(input=tiff_obj.read())

    if process.returncode != 0:
        raise RuntimeError(f"Convert failed: {err.decode()}")
    return jpg_bytes


def get_json_metadata(bucket, key):
    response = s3_client.get_object(Bucket=bucket, Key=key)
    json_metadata = json.loads(response['Body'].read().decode('utf-8'))
    return json_metadata
