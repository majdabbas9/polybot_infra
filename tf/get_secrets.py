import boto3
import json
import sys
import logging

# Enable debug logging for boto3 and botocore
logging.basicConfig(level=logging.INFO)
boto3.set_stream_logger(name='boto3', level=logging.DEBUG)
boto3.set_stream_logger(name='botocore', level=logging.DEBUG)

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='eu-west-1')

    try:
        response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        print(f"🔓 Retrieved secret '{secret_name}':")
        print(json.dumps(secret, indent=2))
        return secret
    except client.exceptions.ResourceNotFoundException:
        print(f"❌ Secret '{secret_name}' not found")
    except Exception as e:
        print(f"❌ Failed to retrieve secret '{secret_name}': {e}")
        raise

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 get_secrets.py <secret_name>")
        print("Example: python3 get_secrets.py majd/dev")
        sys.exit(1)

    secret_name = sys.argv[1]
    get_secret(secret_name)

if __name__ == "__main__":
    main()
