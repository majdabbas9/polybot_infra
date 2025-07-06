import boto3
import json
import sys
import logging

# Configure logging to print to stdout with timestamps
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

# Enable detailed debug logging for boto3/botocore (optional: comment out if too verbose)
boto3.set_stream_logger(name='boto3', level=logging.DEBUG)
boto3.set_stream_logger(name='botocore', level=logging.DEBUG)

def store_secret(secret_name, secret_dict):
    client = boto3.client('secretsmanager', region_name='eu-west-1')

    logging.info(f"🔐 Storing secret: {secret_name}")
    logging.info(f"📦 Payload: {json.dumps(secret_dict, indent=2)}")

    try:
        client.create_secret(
            Name=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        logging.info(f"✅ Created secret: {secret_name}")
    except client.exceptions.ResourceExistsException:
        logging.info(f"ℹ️ Secret already exists, updating: {secret_name}")
        client.put_secret_value(
            SecretId=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        logging.info(f"♻️ Updated secret: {secret_name}")
    except Exception as e:
        logging.exception(f"❌ Failed to store secret {secret_name}: {e}")
        sys.exit(1)  # Exit with error code to fail GitHub Action

def main():
    if len(sys.argv) != 7:
        logging.error("Usage: python3 save_secrets.py <TELEGRAM_TOKEN_DEV> <TELEGRAM_TOKEN_PROD> <DEV_BUCKET_ID> <PROD_BUCKET_ID> <DEV_SQS_URL> <PROD_SQS_URL>")
        sys.exit(1)
    (
        telegram_token_dev,
        telegram_token_prod,
        dev_bucket_id,
        prod_bucket_id,
        dev_sqs_url,
        prod_sqs_url
    ) = sys.argv[1:]

    logging.info("🚀 Starting secret storage process")

    store_secret("majd/dev/polybot", {
        "telegram_token": telegram_token_dev,
        "s3_bucket_id": dev_bucket_id,
        "sqs_queue_url": dev_sqs_url
    })

    store_secret("majd/prod/polybot", {
        "telegram_token": telegram_token_prod,
        "s3_bucket_id": prod_bucket_id,
        "sqs_queue_url": prod_sqs_url
    })

    logging.info("✅ All secrets processed successfully.")

if __name__ == "__main__":
    main()