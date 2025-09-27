from flask import Flask, request, jsonify
from flask_cors import CORS
from pyfcm import FCMNotification
import time

app = Flask(__name__)
CORS(app)

# Replace with your Firebase server key
FCM_API_KEY = "YOUR_FCM_SERVER_KEY"
push_service = FCMNotification(api_key=FCM_API_KEY)

# Simple in-memory user store
users = {
    "user1": {"contacts": [], "last_checkin": None}
}

def send_push(token, title, body, data=None):
    try:
        result = push_service.notify_single_device(
            registration_id=token,
            message_title=title,
            message_body=body,
            data_message=data or {}
        )
        return result
    except Exception as e:
        print("FCM error:", e)
        return None

@app.route("/register_contact", methods=["POST"])
def register_contact():
    data = request.json
    uid = data.get("user_id")
    token = data.get("contact_token")
    if not uid or not token:
        return jsonify({"status":"error","message":"missing fields"}), 400
    users.setdefault(uid, {"contacts": [], "last_checkin": None})
    if token not in users[uid]["contacts"]:
        users[uid]["contacts"].append(token)
    return jsonify({"status":"success","contacts": users[uid]["contacts"]})

@app.route("/send_alert", methods=["POST"])
def send_alert():
    data = request.json
    uid = data.get("user_id")
    lat = data.get("latitude")
    lon = data.get("longitude")
    reason = data.get("reason", "SOS")

    if not uid or lat is None or lon is None:
        return jsonify({"status":"error","message":"missing fields"}), 400
    if uid not in users or not users[uid]["contacts"]:
        return jsonify({"status":"error","message":"user or contacts not found"}), 404

    map_link = f"https://maps.google.com/?q={lat},{lon}"
    title = f"Emergency: {uid}"
    body = f"{uid} triggered an alert ({reason}). Location: {map_link}"
    data_payload = {"user_id": uid, "lat": lat, "lon": lon, "reason": reason}

    results = []
    for token in users[uid]["contacts"]:
        res = send_push(token, title, body, data=data_payload)
        results.append(res)

    return jsonify({"status":"success", "sent_to": len(results)})

@app.route("/checkin_set", methods=["POST"])
def checkin_set():
    data = request.json
    uid = data.get("user_id")
    if not uid:
        return jsonify({"status":"error","message":"missing user_id"}), 400
    users.setdefault(uid, {"contacts": [], "last_checkin": None})
    users[uid]["last_checkin"] = time.time()
    return jsonify({"status":"success","last_checkin": users[uid]["last_checkin"]})

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status":"ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
