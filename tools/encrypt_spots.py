import os, base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

key = os.urandom(32)  # 32 bytes = AES-256
iv = os.urandom(16)   # 16 bytes IV

print(f"KEY (base64): {base64.b64encode(key).decode()}")
print(f"IV (base64):  {base64.b64encode(iv).decode()}")

with open('assets/spots.csv', 'rb') as f:
    data = f.read()

cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
encryptor = cipher.encryptor()

# PKCS7 padding
pad_len = 16 - (len(data) % 16)
data += bytes([pad_len] * pad_len)

encrypted = encryptor.update(data) + encryptor.finalize()

# Format: IV (16 bytes) + ciphertext
with open('assets/spots.csv.enc', 'wb') as f:
    f.write(iv + encrypted)

print(f"Fichier: assets/spots.csv.enc ({len(iv)+len(encrypted)} bytes)")