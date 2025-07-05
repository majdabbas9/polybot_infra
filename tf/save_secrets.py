import boto3
import json
import sys

def store_secret(secret_name, secret_dict):
    client = boto3.client('secretsmanager')
    try:
        client.create_secret(
            Name=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        print(f"✅ Created secret: {secret_name}")
    except client.exceptions.ResourceExistsException:
        client.put_secret_value(
            SecretId=secret_name,
            SecretString=json.dumps(secret_dict)
        )
        print(f"♻️ Updated secret: {secret_name}")

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

    # Save dev secrets to 'majd/dev'
    store_secret("majd/dev", {
        "telegram_token": telegram_token_dev,
        "s3_bucket_id": dev_bucket_id,
        "sqs_queue_url": dev_sqs_url
    })

    # Save prod secrets to 'majd/prod'
    store_secret("majd/prod", {
        "telegram_token": telegram_token_prod,
        "s3_bucket_id": prod_bucket_id,
        "sqs_queue_url": prod_sqs_url
    })

if __name__ == "__main__":
    main()