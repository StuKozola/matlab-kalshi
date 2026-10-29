"""Python signing helpers for Kalshi authentication."""

import base64

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, padding, rsa


def sign_pem(private_key_path, message):
    """Sign message and return base64 text.

    RSA keys use RSA-PSS with SHA-256. Ed25519 keys sign the message directly.
    The key type is detected from the parsed key because the PEM header does
    not identify it.
    """
    with open(private_key_path, "rb") as handle:
        private_key = serialization.load_pem_private_key(handle.read(), password=None)

    data = message.encode("utf-8")
    if isinstance(private_key, ed25519.Ed25519PrivateKey):
        signature = private_key.sign(data)
    elif isinstance(private_key, rsa.RSAPrivateKey):
        signature = private_key.sign(
            data,
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=padding.PSS.DIGEST_LENGTH,
            ),
            hashes.SHA256(),
        )
    else:
        raise ValueError(
            "Unsupported Kalshi private key type: %s" % type(private_key).__name__
        )
    return base64.b64encode(signature).decode("utf-8")
