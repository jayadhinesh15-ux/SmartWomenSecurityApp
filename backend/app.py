from flask import Flask, request, jsonify
from flask_cors import CORS
from pyfcm import FCMNotification

# ---------------- CONFIG ----------------
FCM_API_KEY = "YOUR_FCM_SERVER_KEY"  # Replace with your Firebase server key

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Initialize FCM
push_service = FCMNotification()
push_service.api_key = FCM_API_KEY

# In-memory storage for simplicity
registered_tokens = {}   # {user_id: [list_of_device_tokens]}
checkin_timers = {}      # {user_id: checkin_time_seconds}

# ---------------- ROUTES ----------------

@app.route("/register_contact", methods=["POST"])
def register_contact():
    data = request.json
    user_id = data.get("user_id")
    token = data.get("contact_token")
    
    if not user_id or not token:
        return jsonify({"status": "error", "message": "Missing user_id or token"}), 400
    
    if user_id not in registered_tokens:
        registered_tokens[user_id] = []
    
    if token not in registered_tokens[user_id]:
        registered_tokens[user_id].append(token)
    
    return jsonify({"status": "ok", "tokens": registered_tokens[user_id]})


@app.route("/send_alert", methods=["POST"])
def send_alert():
    data = request.json
    user_id = data.get("user_id")
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    
    if not user_id or not latitude or not longitude:
        return jsonify({"status": "error", "message": "Missing data"}), 400
    
    tokens = registered_tokens.get(user_id, [])
    
    for token in tokens:
        push_service.notify_single_device(
            registration_id=token,
            message_title="SOS Alert",
            message_body=f"{user_id} needs help! Location: {latitude},{longitude}"
        )
    
    return jsonify({"status": "ok", "sent_to": tokens})


@app.route("/checkin_set", methods=["POST"])
def checkin_set():
    data = request.json
    user_id = data.get("user_id")
    checkin_time = data.get("checkin_time")  # seconds
    
    if not user_id or not checkin_time:
        return jsonify({"status": "error", "message": "Missing data"}), 400
    
    checkin_timers[user_id] = checkin_time
    return jsonify({"status": "ok", "message": f"Check-in timer set for {checkin_time} seconds"})


# ---------------- MAIN ----------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
