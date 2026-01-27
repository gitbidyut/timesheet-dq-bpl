import pandas as pd
import boto3
import sys

sns = boto3.client("sns")

DATA_PATH = "/opt/ml/processing/input/timesheet.csv"

df = pd.read_csv(DATA_PATH)

errors = []

# Rule 1: Required columns
required_cols = ["Employee", "Employee Nr.", "Activity Code", "Date", "Hours"]
for col in required_cols:
    if col not in df.columns:
        errors.append(f"Missing column: {col}")

# Rule 2: Null checks
if df["Activity Code"].isnull().mean() > 0.1:
    errors.append("Too many NULL Activity Codes")

# Rule 3: Trim spaces
if df["Description"].str.startswith(" ").any():
    errors.append("Leading spaces in Description")

# Alert on failure
if errors:
    sns.publish(
        TopicArn="<SNS_TOPIC_ARN>",
        Subject="Data Quality Check Failed",
        Message="\n".join(errors)
    )
    sys.exit(1)

print("Data Quality Checks Passed")