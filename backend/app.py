import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from pyfcm import FCMNotification

# ---------------- CONFIG ----------------
SERVICE_ACCOUNT_PATH = "backend/serviceAccountKey.json"
SERVICE_ACCOUNT_JSON = os.environ.get("SERVICE_ACCOUNT_JSON")  # content of JSON

if SERVICE_ACCOUNT_JSON:
    os.makedirs(os.path.dirname(SERVICE_ACCOUNT_PATH), exist_ok=True)
    with open(SERVICE_ACCOUNT_PATH, "w") as f:
        f.write(SERVICE_ACCOUNT_JSON)

if not os.path.exists(SERVICE_ACCOUNT_PATH):
    raise RuntimeError(
        f"Service account file not found at {SERVICE_ACCOUNT_PATH} "
        "or SERVICE_ACCOUNT_JSON env variable missing."
    )

# Initialize Flask and FCM
app = Flask(__name__)
CORS(app)
push_service = FCMNotification(service_account_key=SERVICE_ACCOUNT_PATH)

# In-memory storage
registered_tokens = {}
checkin_timers = {}

# Routes
@app.route("/register_contact", methods=["POST"])
def register_contact():
    data = request.json
    user_id = data.get("user_id")
    token = data.get("contact_token")
    if not user_id or not token:
        return jsonify({"status": "error", "message": "Missing user_id or token"}), 400
    registered_tokens.setdefault(user_id, [])
    if token not in registered_tokens[user_id]:
        registered_tokens[user_id].append(token)
    return jsonify({"status": "ok", "tokens": registered_tokens[user_id]})

@app.route("/send_alert", methods=["POST"])
def send_alert():
    data = request.json
    user_id = data.get("user_id")
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    if not user_id or latitude is None or longitude is None:
        return jsonify({"status": "error", "message": "Missing data"}), 400
    tokens = registered_tokens.get(user_id, [])
    for token in tokens:
        try:
            push_service.notify_single_device(
                registration_id=token,
                message_title="SOS Alert",
                message_body=f"{user_id} needs help! Location: {latitude},{longitude}"
            )
        except Exception as e:
            print("FCM send error:", e)
    return jsonify({"status": "ok", "sent_to": tokens})

@app.route("/checkin_set", methods=["POST"])
def checkin_set():
    data = request.json
    user_id = data.get("user_id")
    checkin_time = data.get("checkin_time")
    if not user_id or checkin_time is None:
        return jsonify({"status": "error", "message": "Missing data"}), 400
    checkin_timers[user_id] = checkin_time
    return jsonify({"status": "ok", "message": f"Check-in timer set for {checkin_time} seconds"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
