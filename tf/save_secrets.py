import boto3
import json
import sys
import logging

# Enable debug logging for boto3 and botocore
logging.basicConfig(level=logging.INFO)
boto3.set_stream_logger(name='boto3', level=logging.DEBUG)
boto3.set_stream_logger(name='botocore', level=logging.DEBUG)

def store_secret(secret_name, secret_dict):
    client = boto3.client('secretsmanager', region_name='eu-west-1')  # ✅ Fix typo in region

    print(f"🔐 Storing secret: {secret_name}")
    print(f"📦 Payload: {json.dumps(secret_dict, indent=2)}")

    try:
        client.create_secret(
            Name=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        print(f"✅ Created secret: {secret_name}")
    except client.exceptions.ResourceExistsException:
        print(f"ℹ️ Secret already exists, updating: {secret_name}")
        client.put_secret_value(
            SecretId=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        print(f"♻️ Updated secret: {secret_name}")
    except Exception as e:
        print(f"❌ Failed to store secret {secret_name}: {e}")
        raise

def main():
    if len(sys.argv) != 7:
        print("Usage: python3 save_secrets.py <TELEGRAM_TOKEN_DEV> <TELEGRAM_TOKEN_PROD> <DEV_BUCKET_ID> <PROD_BUCKET_ID> <DEV_SQS_URL> <PROD_SQS_URL>")
        sys.exit(1)

    (
        telegram_token_dev,
        telegram_token_prod,
        dev_bucket_id,
        prod_bucket_id,
        dev_sqs_url,
        prod_sqs_url
    ) = sys.argv[1:]

    print("🚀 Starting secret storage process")

    store_secret("majd/dev", {
        "telegram_token": telegram_token_dev,
        "s3_bucket_id": dev_bucket_id,
        "sqs_queue_url": dev_sqs_url
    })

    store_secret("majd/prod", {
        "telegram_token": telegram_token_prod,
        "s3_bucket_id": prod_bucket_id,
        "sqs_queue_url": prod_sqs_url
    })

    print("✅ All secrets processed")

if __name__ == "__main__":
    main()
