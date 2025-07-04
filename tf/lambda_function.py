import boto3
from datetime import datetime, timedelta

REGION = "eu-west-1"
SSM_PARAM = "/k8s/worker/join-command-majd"

ssm = boto3.client("ssm", region_name=REGION)
ec2 = boto3.client("ec2", region_name=REGION)

def lambda_handler(event, context):
    print("✅ Lambda triggered by SNS")

    instance_id = get_control_plane_instance_id()
    if not instance_id:
        print("❌ No running control plane instance found")
        return {"statusCode": 500}

    try:
        param = ssm.get_parameter(Name=SSM_PARAM, WithDecryption=True)
        value = param["Parameter"]["Value"]
        timestamp = param["Parameter"]["LastModifiedDate"]
        print("🧪 Current token:", value)
        print("⏱️ Last updated:", timestamp)

        if True or (datetime.now(timestamp.tzinfo) - timestamp) > timedelta(hours=23):
            print("🔁 Token expired — generating a new one")
            generate_new_token(instance_id)
        else:
            print("✅ Token is still valid")

    except ssm.exceptions.ParameterNotFound:
        print("❌ Token parameter not found — generating a new one")
        generate_new_token(instance_id)

    return {"statusCode": 200}

def get_control_plane_instance_id():
    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Name", "Values": ["majd-k8s-cp"]},
            {"Name": "instance-state-name", "Values": ["running"]}
        ]
    )
    reservations = response.get("Reservations", [])
    if reservations and reservations[0]["Instances"]:
        return reservations[0]["Instances"][0]["InstanceId"]
    return None

def generate_new_token(instance_id):
    ssm_cmd = "kubeadm token create --print-join-command"
    response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [ssm_cmd]},
    )
    command_id = response["Command"]["CommandId"]

    # Wait for the command to finish
    waiter = ssm.get_waiter("command_executed")
    waiter.wait(CommandId=command_id, InstanceId=instance_id)

    # Get output
    output = ssm.get_command_invocation(
        CommandId=command_id,
        InstanceId=instance_id,
    )
    join_cmd = output["StandardOutputContent"].strip()
    print("📦 New join command:", join_cmd)

    ssm.put_parameter(
        Name=SSM_PARAM,
        Value=join_cmd,
        Type="SecureString",
        Overwrite=True
    )
    print("✅ New join command saved to SSM")