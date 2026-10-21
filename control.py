#!/usr/bin/env python3
import argparse
import json
import socket

SOCKET = "/var/mobile/Library/Caches/com.example.keychainclear.sock"

def send(command: str) -> str:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(5)
        s.connect(SOCKET)
        s.sendall((command + "\n").encode())
        chunks = []
        while True:
            data = s.recv(4096)
            if not data:
                break
            chunks.append(data)
    return b"".join(chunks).decode(errors="replace").strip()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["ping", "status", "clear"])
    args = parser.parse_args()
    result = send(args.command)
    try:
        print(json.dumps(json.loads(result), ensure_ascii=False, indent=2))
    except Exception:
        print(result)

if __name__ == "__main__":
    main()
