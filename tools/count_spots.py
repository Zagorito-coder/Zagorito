#!/usr/bin/env python3
"""Compte le nombre de spots dans spots.csv.enc"""
import base64
from cryptography.fernet import Fernet
import os

# Clé depuis .env ou fallback
key = os.environ.get('CSV_ENCRYPTION_KEY', 'jUrorAkQco3Cw2Q1TjjuGm9ctZYOLOe39htjuvBhGTQ=')

with open('assets/spots.csv.enc', 'rb') as f:
    data = f.read()

# Fernet standard : 32 bytes header + IV + ciphertext + HMAC
# Le format est légèrement custom, on extrait juste
cipher = Fernet(key.encode())
decrypted = cipher.decrypt(data)
lines = decrypted.decode('utf-8').strip().split('\n')
print(f"Nombre de spots : {len(lines)}")