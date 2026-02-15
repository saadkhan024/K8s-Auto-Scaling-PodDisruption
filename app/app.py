from flask import Flask, jsonify
import os
import time
import hashlib

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "Cluster Autoscaler Demo App",
        "pod": os.environ.get('HOSTNAME', 'unknown'),
        "status": "running"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/load')
def cpu_load():
    """Simulate CPU-intensive work to trigger scaling"""
    start = time.time()
    result = 0
    
    # Heavy computation
    for i in range(5000000):
        result += hashlib.sha256(str(i).encode()).hexdigest()
    
    duration = time.time() - start
    return jsonify({
        "pod": os.environ.get('HOSTNAME', 'unknown'),
        "computation_time": f"{duration:.2f}s",
        "message": "Heavy computation completed"
    })

@app.route('/memory')
def memory_load():
    """Simulate memory-intensive work"""
    # Allocate 100MB of memory
    data = ' ' * (100 * 1024 * 1024)
    return jsonify({
        "pod": os.environ.get('HOSTNAME', 'unknown'),
        "memory_allocated": "100MB",
        "message": "Memory allocated"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
