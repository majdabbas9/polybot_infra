import yaml
import boto3
import argparse
import logging
import sys

# Configure logging to stdout for GitHub Actions
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger()

def update_image_from_ssm(src_yaml, dest_yaml, ssm_param_name, aws_region):
    ssm = boto3.client('ssm', region_name=aws_region)

    logger.info("Fetching image name from SSM Parameter Store")
    response = ssm.get_parameter(Name=ssm_param_name, WithDecryption=True)
    new_image_name = response['Parameter']['Value']
    logger.info(f"Got image name from SSM: {new_image_name}")

    with open(src_yaml, 'r') as f:
        deployment = yaml.safe_load(f)

    logger.info("Updating YAML file")
    containers = deployment['spec']['template']['spec']['containers']
    for container in containers:
        if 'image' in container:
            container['image'] = new_image_name

    with open(dest_yaml, 'w') as f:
        yaml.safe_dump(deployment, f)

    logger.info(f"Updated YAML saved to {dest_yaml}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Update Kubernetes YAML image name from AWS SSM Parameter Store')
    parser.add_argument('--src', required=True, help='Source YAML file path')
    parser.add_argument('--dest', required=True, help='Destination YAML file path')
    parser.add_argument('--ssm', required=True, help='AWS SSM parameter name to read')
    parser.add_argument('--region', default='us-east-1', help='AWS region for SSM (default: us-east-1)')

    args = parser.parse_args()

    update_image_from_ssm(args.src, args.dest, args.ssm, args.region)