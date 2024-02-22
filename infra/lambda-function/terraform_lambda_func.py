import json
import boto3

dynamodb = boto3.resource("dynamodb")
views_table = dynamodb.Table("kubafara-views")

def lambda_handler(event, context):
    response = views_table.get_item(Key={'id' : '1'})
    v_count = response["Item"]["view_count"]
    v_count = str(int(v_count) + 1)
    
    response = views_table.update_item(
        Key={'id' : '1'},
        UpdateExpression='set view_count = :c',
        ExpressionAttributeValues={':c': v_count},
        ReturnValues='UPDATED_NEW'
        )
        
    return {'Count': v_count}