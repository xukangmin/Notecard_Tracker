import json
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Use the application default credentials
cred = credentials.Certificate("./xx.json")

firebase_admin.initialize_app(cred, {
  'projectId': 'lovetracker-xx',
})

db = firestore.client()

local_col = db.collection(u'location_data')

def lambda_handler(event, context):   

    id = event['event']

    local_col.document(id).set(event)

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }