import importlib
import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


LAMBDA_DIR = Path(__file__).parent
sys.path.insert(0, str(LAMBDA_DIR))
with patch.dict(os.environ, {"CTD_BUCKET": "test-ctd"}), patch("boto3.client"):
    lambda_handler = importlib.import_module("lambda_handler")


class LambdaHandlerTests(unittest.TestCase):
    def setUp(self):
        self.s3_client = Mock()
        lambda_handler.s3_client = self.s3_client

    def test_get_json_metadata_reads_and_decodes_s3_object(self):
        metadata = [{"UUID": "asset-123", "IAID": "iaid-456"}]
        self.s3_client.get_object.return_value = {
            "Body": io.BytesIO(json.dumps(metadata).encode("utf-8"))
        }

        result = lambda_handler.get_json_metadata("source-bucket", "metadata.json")

        self.assertEqual(result, metadata)
        self.s3_client.get_object.assert_called_once_with(
            Bucket="source-bucket", Key="metadata.json"
        )

    @patch("lambda_handler.subprocess.Popen")
    def test_convert_file_returns_converted_bytes(self, popen):
        self.s3_client.download_fileobj.side_effect = (
            lambda bucket, key, destination: destination.write(b"tiff-data")
        )
        process = Mock(returncode=0)
        process.communicate.return_value = (b"jpeg-data", b"")
        popen.return_value = process

        result = lambda_handler.convert_file("source-bucket", "asset-123/file-1")

        self.assertEqual(result, b"jpeg-data")
        self.s3_client.download_fileobj.assert_called_once()
        args, kwargs = popen.call_args
        self.assertEqual(args[0], ["/opt/bin/convert", "tiff:-", "jpg:-"])
        self.assertIs(kwargs["stdin"], lambda_handler.subprocess.PIPE)
        self.assertIs(kwargs["stdout"], lambda_handler.subprocess.PIPE)
        self.assertIs(kwargs["stderr"], lambda_handler.subprocess.PIPE)
        process.communicate.assert_called_once_with(input=b"tiff-data")

    @patch("lambda_handler.subprocess.Popen")
    def test_convert_file_raises_when_conversion_fails(self, popen):
        process = Mock(returncode=1)
        process.communicate.return_value = (b"", b"invalid TIFF")
        popen.return_value = process

        with self.assertRaisesRegex(RuntimeError, "Convert failed: invalid TIFF"):
            lambda_handler.convert_file("source-bucket", "asset-123/file-1")

    @patch("lambda_handler.convert_file", return_value=b"x" * 2501)
    @patch("lambda_handler.get_json_metadata")
    def test_handler_copies_files_converts_tiffs_and_uploads_sorted_metadata(
        self, get_metadata, convert_file
    ):
        get_metadata.return_value = [
            {
                "UUID": "asset-123",
                "IAID": "iaid-456",
                "fileId": "file-10",
                "Filename": "image10.png",
                "checksum_sha256": "checksum-10",
            },
            {
                "UUID": "asset-123",
                "IAID": "iaid-456",
                "fileId": "file-2",
                "Filename": "image2.tif",
                "checksum_sha256": "checksum-2",
            },
        ]
        self.s3_client.head_object.return_value = {"ContentLength": 3400}
        event = {
            "Records": [
                {
                    "body": json.dumps(
                        {
                            "Records": [
                                {
                                    "s3": {
                                        "bucket": {"name": "source-bucket"},
                                        "object": {"key": "metadata.json"},
                                    }
                                }
                            ]
                        }
                    )
                }
            ]
        }

        lambda_handler.lambda_handler(event, None)

        get_metadata.assert_called_once_with("source-bucket", "metadata.json")
        self.s3_client.copy.assert_called_once_with(
            {"Bucket": "source-bucket", "Key": "asset-123/file-10"},
            "test-ctd",
            "files/iaid-456/file-10.png",
        )
        self.s3_client.head_object.assert_called_once_with(
            Bucket="source-bucket", Key="asset-123/file-10"
        )
        convert_file.assert_called_once_with("source-bucket", "asset-123/file-2")

        uploaded_files = [
            call.args[2] for call in self.s3_client.upload_fileobj.call_args_list
        ]
        self.assertEqual(
            uploaded_files,
            ["files/iaid-456/file-2.jpg", "metadata/iaid-456.json"],
        )
        metadata_body = self.s3_client.upload_fileobj.call_args_list[-1].args[0]
        replica_metadata = json.loads(metadata_body.getvalue().decode("utf-8"))
        self.assertEqual(
            [file["originalName"] for file in replica_metadata["files"]],
            ["image2.tif", "image10.png"],
        )
        self.assertEqual(
            replica_metadata,
            {
                "files": [
                    {
                        "checkSum": "checksum-2",
                        "format": "jpg",
                        "name": "file-2",
                        "originalName": "image2.tif",
                        "size": 2,
                    },
                    {
                        "checkSum": "checksum-10",
                        "format": "png",
                        "name": "file-10",
                        "originalName": "image10.png",
                        "size": 3,
                    },
                ],
                "replicaId": "asset-123",
                "origination": "Born Digital",
                "totalSize": 5,
            },
        )
        converted_upload = self.s3_client.upload_fileobj.call_args_list[0]
        self.assertEqual(converted_upload.args[0].getvalue(), b"x" * 2501)
        self.assertEqual(converted_upload.args[1:], ("test-ctd", "files/iaid-456/file-2.jpg"))


if __name__ == "__main__":
    unittest.main()
