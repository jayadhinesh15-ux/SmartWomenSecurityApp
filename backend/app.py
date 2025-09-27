# backend/app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, messaging
import os
import json
import logging

logging.basicConfig(level=logging.INFO)

app = Flask(__name__)
CORS(app)

# Load Firebase credentials from environment variable FIREBASE_CRED
cred_json = os.environ.get("FIREBASE_CRED")
if cred_json:
    try:
        cred_dict = json.loads(cred_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        logging.info("Initialized Firebase Admin SDK")
    except Exception as e:
        logging.exception("Failed to initialize Firebase Admin SDK: %s", e)
        raise
else:
    raise RuntimeError("FIREBASE_CRED not set in environment")

# Simple in-memory store for contact token (demo only)
contact_token = None

@app.route('/register_contact', methods=['POST'])
def register_contact():
    global contact_token
    data = request.get_json() or {}
    token = data.get('token')
    if not token:
        return jsonify({"error": "Missing token"}), 400
    contact_token = token
    logging.info("Registered contact token: %s", token[:20] + "...")
    return jsonify({"status": "Contact registered"}), 200

@app.route('/send_sos', methods=['POST'])
def send_sos():
    global contact_token
    if not contact_token:
        return jsonify({"error": "No contact registered"}), 400
    data = request.get_json() or {}
    message_body = data.get('message', 'Emergency! Please help!')
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title='SOS Alert',
                body=message_body
            ),
            token=contact_token
        )
        response = messaging.send(message)
        logging.info("Sent message: %s", response)
        return jsonify({"status": "Alert sent", "response": response}), 200
    except Exception as e:
        logging.exception("Failed to send message: %s", e)
        return jsonify({"error": "Failed to send message", "details": str(e)}), 500

@app.route('/status', methods=['GET'])
def status():
    return jsonify({"status": "ok", "contact_registered": contact_token is not None}), 200

@app.route('/')
def home():
    return "Backend running!", 200

if __name__ == '__main__':
    # For local development only. Render will use gunicorn.
    app.run(host='0.0.0.0', port=int(os.environ.get("PORT", 5000)))
