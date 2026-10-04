from flask import Flask, jsonify, request

app = Flask(__name__)


@app.route("/")
def home():
    response = jsonify({
        "message": "Backend is running"
    })
    response.headers["X-Backend"] = "B"
    response.headers["ETag"] = '"backend-home-v1"'

    if request.if_none_match.contains("backend-home-v1"):
        return "", 304
    
    return response


@app.route("/api/status")
def status():
    response = jsonify({
        "backend": "B",
        "status": "ok"
    })
    response.headers["X-Backend"] = "B"
    response.headers["ETag"] = '"backend-home-v1"'

    if request.if_none_match.contains("backend-home-v1"):
        return "", 304
    return response


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3002)
