import json
import boto3
import os
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DDB_TABLE'])

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        name = body.get('name')
        email = body.get('email')
        message = body.get('message')

        submission_id = str(uuid.uuid4())
        table.put_item(Item={
            'submissionId': submission_id,
            'name': name,
            'email': email,
            'message': message
        })

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': 'https://formbridgegod.netlify.app',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({'id': submission_id})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': 'https://formbridgegod.netlify.app',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({'error': str(e)})
        }
