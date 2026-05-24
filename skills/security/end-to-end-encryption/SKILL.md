---
name: end-to-end-encryption
description: Implement end-to-end encryption (E2EE) for web and mobile applications using libsodium, Web Crypto API, and Signal Protocol patterns. Covers key exchange, symmetric encryption, digital signatures, sealed boxes, and key management without server-side key access.
version: 1.0.0
tags: [encryption, e2ee, libsodium, webcrypto, signal-protocol, cryptography, security, privacy, backend, frontend]
---

# End-to-End Encryption

## Overview

End-to-end encryption ensures only the communicating parties can read messages — the server stores ciphertext it cannot decrypt. The fundamental building blocks are asymmetric key exchange (X25519 Diffie-Hellman), symmetric encryption (XSalsa20-Poly1305 or AES-GCM), and digital signatures (Ed25519). Modern implementations use libsodium's high-level abstractions to avoid low-level cryptographic mistakes, with the Web Crypto API providing browser-native acceleration.

## When to Use

- Messaging applications where server compromise must not expose message content
- Storing sensitive user data (medical records, financial info) where server-side breaches are a concern
- File sharing that requires zero-knowledge storage (server stores ciphertext only)
- Healthcare or legal applications with strict data privacy requirements (HIPAA, GDPR)
- Multi-party secrets (password managers, shared team vaults)
- Any system where regulatory compliance requires proving the server cannot read user data

## Step-by-Step Workflow

### 1. Symmetric Encryption with libsodium (Python/Node)

```python
# pip install pynacl
# NaCl / libsodium high-level API — use these, not raw primitives

from nacl.secret import SecretBox
from nacl.utils import random
from nacl.encoding import Base64Encoder
import base64

def generate_key() -> bytes:
    """Generate a 256-bit random symmetric key."""
    return random(SecretBox.KEY_SIZE)  # 32 bytes

def encrypt(plaintext: str | bytes, key: bytes) -> str:
    """
    Encrypt with XSalsa20-Poly1305.
    Returns base64 nonce+ciphertext — authenticated encryption.
    """
    box = SecretBox(key)
    if isinstance(plaintext, str):
        plaintext = plaintext.encode("utf-8")
    encrypted = box.encrypt(plaintext)  # Includes random nonce
    return base64.b64encode(encrypted).decode()

def decrypt(ciphertext_b64: str, key: bytes) -> str:
    """Decrypt and verify authentication tag."""
    box = SecretBox(key)
    ciphertext = base64.b64decode(ciphertext_b64)
    plaintext = box.decrypt(ciphertext)  # Raises CryptoError if tampered
    return plaintext.decode("utf-8")

# Usage
key = generate_key()
ct = encrypt("Hello, secret world!", key)
pt = decrypt(ct, key)
assert pt == "Hello, secret world!"

# Store key securely (e.g., derived from user password)
# NEVER log or transmit the key unencrypted
```

```typescript
// Node.js / browser — libsodium-wrappers
// npm install libsodium-wrappers

import sodium from "libsodium-wrappers";

await sodium.ready;

export function generateKey(): Uint8Array {
  return sodium.randombytes_buf(sodium.crypto_secretbox_KEYBYTES);
}

export function encrypt(plaintext: string, key: Uint8Array): string {
  const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
  const ciphertext = sodium.crypto_secretbox_easy(
    sodium.from_string(plaintext),
    nonce,
    key
  );
  // Prepend nonce to ciphertext for storage
  const combined = new Uint8Array(nonce.length + ciphertext.length);
  combined.set(nonce);
  combined.set(ciphertext, nonce.length);
  return sodium.to_base64(combined);
}

export function decrypt(ciphertextB64: string, key: Uint8Array): string {
  const combined = sodium.from_base64(ciphertextB64);
  const nonce = combined.slice(0, sodium.crypto_secretbox_NONCEBYTES);
  const ciphertext = combined.slice(sodium.crypto_secretbox_NONCEBYTES);
  const plaintext = sodium.crypto_secretbox_open_easy(ciphertext, nonce, key);
  if (!plaintext) throw new Error("Decryption failed — message tampered");
  return sodium.to_string(plaintext);
}
```

### 2. Asymmetric Key Exchange (Public Key Encryption)

```python
# Sealed box — encrypt to recipient's public key (no shared secret needed)
from nacl.public import PrivateKey, PublicKey, SealedBox
import base64

def generate_keypair() -> tuple[bytes, bytes]:
    """Returns (private_key_b64, public_key_b64)."""
    private_key = PrivateKey.generate()
    return (
        base64.b64encode(bytes(private_key)).decode(),
        base64.b64encode(bytes(private_key.public_key)).decode(),
    )

def encrypt_to_recipient(message: str, recipient_public_key_b64: str) -> str:
    """Encrypt a message that only recipient can decrypt with their private key."""
    pub_key = PublicKey(base64.b64decode(recipient_public_key_b64))
    box = SealedBox(pub_key)
    ciphertext = box.encrypt(message.encode("utf-8"))
    return base64.b64encode(ciphertext).decode()

def decrypt_from_sender(ciphertext_b64: str, recipient_private_key_b64: str) -> str:
    """Decrypt a sealed box message using recipient's private key."""
    priv_key = PrivateKey(base64.b64decode(recipient_private_key_b64))
    box = SealedBox(priv_key)
    plaintext = box.decrypt(base64.b64decode(ciphertext_b64))
    return plaintext.decode("utf-8")

# Key exchange with Box (mutual, provides sender authentication)
from nacl.public import Box

def create_shared_box(
    sender_private_key_b64: str,
    recipient_public_key_b64: str
) -> Box:
    """Create a Box for authenticated encryption between two parties."""
    priv = PrivateKey(base64.b64decode(sender_private_key_b64))
    pub = PublicKey(base64.b64decode(recipient_public_key_b64))
    return Box(priv, pub)

def encrypt_message(box: Box, message: str) -> str:
    return base64.b64encode(box.encrypt(message.encode())).decode()

def decrypt_message(box: Box, ciphertext_b64: str) -> str:
    return box.decrypt(base64.b64decode(ciphertext_b64)).decode()
```

### 3. Web Crypto API (Browser-Native, Zero Dependencies)

```typescript
// Pure Web Crypto API — works in any modern browser without libraries
// Uses AES-GCM (authenticated encryption) and ECDH (key exchange)

// Generate an ECDH key pair for key exchange
async function generateECDHKeyPair(): Promise<CryptoKeyPair> {
  return crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,   // extractable — for export
    ["deriveKey"]
  );
}

// Derive shared symmetric key from two parties' keys
async function deriveSharedKey(
  myPrivateKey: CryptoKey,
  theirPublicKey: CryptoKey
): Promise<CryptoKey> {
  return crypto.subtle.deriveKey(
    { name: "ECDH", public: theirPublicKey },
    myPrivateKey,
    { name: "AES-GCM", length: 256 },
    false,  // not extractable
    ["encrypt", "decrypt"]
  );
}

// Encrypt with AES-GCM
async function encrypt(plaintext: string, key: CryptoKey): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));  // 96-bit IV
  const encoded = new TextEncoder().encode(plaintext);

  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoded
  );

  // Combine IV + ciphertext, base64 encode
  const combined = new Uint8Array(iv.byteLength + ciphertext.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(ciphertext), iv.byteLength);
  return btoa(String.fromCharCode(...combined));
}

async function decrypt(ciphertextB64: string, key: CryptoKey): Promise<string> {
  const combined = Uint8Array.from(atob(ciphertextB64), c => c.charCodeAt(0));
  const iv = combined.slice(0, 12);
  const ciphertext = combined.slice(12);

  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext
  );
  return new TextDecoder().decode(plaintext);
}

// Export public key as JWK for transmission
async function exportPublicKey(key: CryptoKey): Promise<string> {
  const jwk = await crypto.subtle.exportKey("jwk", key);
  return JSON.stringify(jwk);
}

async function importPublicKey(jwkString: string): Promise<CryptoKey> {
  const jwk = JSON.parse(jwkString);
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "ECDH", namedCurve: "P-256" },
    true,
    []  // No usages for public key
  );
}
```

### 4. Password-Based Key Derivation (PBKDF2 / Argon2)

```python
# Derive encryption key from user password — never store the password
from nacl.pwhash import argon2id
from nacl.utils import random

def derive_key_from_password(password: str, salt: bytes = None) -> tuple[bytes, bytes]:
    """
    Derive a 32-byte key from password using Argon2id.
    Returns (key, salt) — salt must be stored alongside ciphertext.
    """
    if salt is None:
        salt = random(argon2id.SALTBYTES)  # 16 random bytes

    key = argon2id.kdf(
        32,                              # Output size (32 bytes = 256 bits)
        password.encode("utf-8"),
        salt,
        opslimit=argon2id.OPSLIMIT_INTERACTIVE,  # ~0.5s on modern hardware
        memlimit=argon2id.MEMLIMIT_INTERACTIVE,  # ~64MB memory
    )
    return key, salt

# User vault pattern — encrypt user data with password-derived key
import json

def create_vault(password: str, secrets: dict) -> dict:
    """Create an encrypted vault from user password and secrets dict."""
    key, salt = derive_key_from_password(password)
    plaintext = json.dumps(secrets)
    ciphertext = encrypt(plaintext, key)
    return {
        "salt": base64.b64encode(salt).decode(),
        "ciphertext": ciphertext
    }

def open_vault(password: str, vault: dict) -> dict:
    """Open an encrypted vault with user password."""
    salt = base64.b64decode(vault["salt"])
    key, _ = derive_key_from_password(password, salt)
    plaintext = decrypt(vault["ciphertext"], key)
    return json.loads(plaintext)
```

### 5. Digital Signatures

```python
# Ed25519 signatures — prove message authenticity and integrity
from nacl.signing import SigningKey, VerifyKey
import base64

def generate_signing_keypair() -> tuple[str, str]:
    """Returns (signing_key_b64, verify_key_b64)."""
    sk = SigningKey.generate()
    return (
        base64.b64encode(bytes(sk)).decode(),
        base64.b64encode(bytes(sk.verify_key)).decode(),
    )

def sign_message(message: str | bytes, signing_key_b64: str) -> str:
    """Sign a message. Returns base64 signature."""
    if isinstance(message, str):
        message = message.encode("utf-8")
    sk = SigningKey(base64.b64decode(signing_key_b64))
    signed = sk.sign(message)
    return base64.b64encode(signed.signature).decode()

def verify_signature(
    message: str | bytes,
    signature_b64: str,
    verify_key_b64: str
) -> bool:
    """Verify a message signature. Raises if invalid."""
    if isinstance(message, str):
        message = message.encode("utf-8")
    vk = VerifyKey(base64.b64decode(verify_key_b64))
    sig = base64.b64decode(signature_b64)
    try:
        vk.verify(message, sig)
        return True
    except Exception:
        return False
```

## Key Commands Reference

```bash
# Python — pynacl
pip install pynacl
python -c "from nacl.secret import SecretBox; print('NaCl OK')"

# Node.js — libsodium
npm install libsodium-wrappers
npm install libsodium-wrappers-sumo  # Full API

# Generate a test key and encrypt
python3 -c "
from nacl.secret import SecretBox
from nacl.utils import random
import base64
key = random(SecretBox.KEY_SIZE)
box = SecretBox(key)
ct = box.encrypt(b'hello world')
pt = box.decrypt(ct)
print(f'Key: {base64.b64encode(key).decode()}')
print(f'Plaintext: {pt}')
"

# OpenSSL reference (not recommended for app code — use libsodium)
# Generate X25519 keypair
openssl genpkey -algorithm X25519 -out private.pem
openssl pkey -in private.pem -pubout -out public.pem

# Verify AES-GCM works
openssl enc -aes-256-gcm -k "password" -in plaintext.txt -out encrypted.bin
openssl enc -d -aes-256-gcm -k "password" -in encrypted.bin
```

## Common Patterns

### Pattern 1: Zero-Knowledge File Storage

```python
# Client encrypts before upload — server never sees plaintext
def encrypt_file(file_path: str, user_key: bytes) -> bytes:
    """Encrypt a file for zero-knowledge storage."""
    with open(file_path, "rb") as f:
        plaintext = f.read()
    box = SecretBox(user_key)
    return bytes(box.encrypt(plaintext))

def decrypt_file(ciphertext: bytes, user_key: bytes) -> bytes:
    """Decrypt downloaded file ciphertext."""
    box = SecretBox(user_key)
    return bytes(box.decrypt(ciphertext))

# File key wrapped in user's master key (allows key rotation)
def create_file_record(file_content: bytes, master_key: bytes) -> dict:
    """Each file gets a random key, wrapped by the master key."""
    file_key = generate_key()
    encrypted_content = encrypt(file_content, file_key)
    wrapped_key = encrypt(file_key, master_key)  # Encrypt the file key
    return {
        "content_ciphertext": encrypted_content,
        "wrapped_key": wrapped_key,
    }
```

### Pattern 2: Secure Channel Between Two Parties

```typescript
// Establish a secure channel using ECDH, then communicate with AES-GCM
class SecureChannel {
  private sharedKey: CryptoKey | null = null;
  private myKeyPair: CryptoKeyPair;

  async init(): Promise<string> {
    this.myKeyPair = await generateECDHKeyPair();
    return await exportPublicKey(this.myKeyPair.publicKey);
  }

  async acceptHandshake(theirPublicKeyJwk: string): Promise<void> {
    const theirKey = await importPublicKey(theirPublicKeyJwk);
    this.sharedKey = await deriveSharedKey(this.myKeyPair.privateKey, theirKey);
  }

  async send(message: string): Promise<string> {
    if (!this.sharedKey) throw new Error("Channel not established");
    return encrypt(message, this.sharedKey);
  }

  async receive(ciphertext: string): Promise<string> {
    if (!this.sharedKey) throw new Error("Channel not established");
    return decrypt(ciphertext, this.sharedKey);
  }
}
```

### Pattern 3: Secure Envelope (Hybrid Encryption)

```python
# Hybrid: encrypt data with fast symmetric key, encrypt that key with RSA/EC
def encrypt_envelope(plaintext: bytes, recipient_public_key_b64: str) -> dict:
    """
    Encrypt large data efficiently:
    1. Generate random symmetric key
    2. Encrypt data with symmetric key (fast)
    3. Encrypt symmetric key with recipient's public key
    """
    # Random symmetric key for this message
    data_key = generate_key()
    # Encrypt the data
    encrypted_data = encrypt(plaintext.decode(), data_key)
    # Encrypt the data key for the recipient
    encrypted_key = encrypt_to_recipient(
        base64.b64encode(data_key).decode(),
        recipient_public_key_b64
    )
    return {
        "encrypted_data": encrypted_data,
        "encrypted_key": encrypted_key,
    }

def decrypt_envelope(envelope: dict, recipient_private_key_b64: str) -> bytes:
    """Decrypt a sealed envelope."""
    data_key_b64 = decrypt_from_sender(
        envelope["encrypted_key"],
        recipient_private_key_b64
    )
    data_key = base64.b64decode(data_key_b64)
    return decrypt(envelope["encrypted_data"], data_key).encode()
```

## Pitfalls to Avoid

1. **Reusing nonces with the same key**: AES-GCM and NaCl's SecretBox become completely insecure if you encrypt two messages with the same key and nonce — an attacker can XOR the ciphertexts to recover both plaintexts. Always generate a fresh random nonce for every encryption operation. The nonce does not need to be secret — store it alongside the ciphertext.

2. **Storing private keys server-side**: True E2EE requires that private keys never leave the client. If you store private keys on the server (even encrypted), you have the server's decryption key and can be compelled to decrypt or be compromised. Private keys belong exclusively on the client device, derived from user passwords via Argon2id, or stored in hardware security modules (HSM/TPM/Secure Enclave).

3. **Rolling your own cryptography**: Never implement low-level crypto primitives (AES, RSA, elliptic curves) yourself. Use high-level libraries (libsodium, Web Crypto API, PyNaCl) that handle nonce generation, padding, authentication tags, and timing attack resistance. The single most common mistake in cryptography is implementing correct algorithms but making implementation errors that undermine security.

## Related Skills

- `api-security-hardening` — Broader API security including TLS configuration
- `container-security` — Securing secrets in containerized environments
- `oauth2-oidc-implementation` — Authentication that complements E2EE
- `zero-knowledge-proofs` — Related privacy-preserving cryptography
- `soc2-compliance` — Compliance requirements that E2EE satisfies

## GitNexus Index

```json
{
  "skill": "end-to-end-encryption",
  "category": "security",
  "triggers": ["end-to-end encryption", "E2EE", "libsodium", "NaCl encryption", "AES-GCM", "Web Crypto API", "symmetric encryption", "ECDH key exchange", "digital signature", "Ed25519", "zero-knowledge storage", "Argon2id", "sealed box"],
  "outputs": ["SecretBox encrypt/decrypt", "generate_keypair", "encrypt_to_recipient", "crypto.subtle AES-GCM", "derive_key_from_password", "create_vault", "encrypt_envelope", "SecureChannel"],
  "complexity": "high",
  "tools": ["pynacl", "libsodium-wrappers", "webcrypto", "python", "typescript", "openssl"]
}
```
