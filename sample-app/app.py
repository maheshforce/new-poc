from flask import Flask, request, jsonify
import os

app = Flask(__name__)
DATA_DIR = os.getenv('DATA_DIR', '/app/data')
FILE_PATH = os.path.join(DATA_DIR, 'test.txt')

@app.route('/healthz', methods=['GET'])
def healthz():
    return "OK", 200

@app.route('/data', methods=['POST'])
def write_data():
    content = request.json.get('content', 'Default Content')
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(FILE_PATH, 'w') as f:
            f.write(content)
        return jsonify({"status": "success", "message": f"Wrote content to {FILE_PATH}"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/data', methods=['GET'])
def read_data():
    try:
        if not os.path.exists(FILE_PATH):
            return jsonify({"status": "not_found", "message": "No file found at /app/data/test.txt"}), 404
        with open(FILE_PATH, 'r') as f:
            content = f.read()
        return jsonify({"status": "success", "content": content}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
