"""Python signing helpers for Kalshi authentication."""

import base64

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def sign_pem(private_key_path, message):
    """Sign message with RSA-PSS SHA-256 and return base64 text."""
    with open(private_key_path, "rb") as handle:
        private_key = serialization.load_pem_private_key(handle.read(), password=None)

    signature = private_key.sign(
        message.encode("utf-8"),
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.DIGEST_LENGTH,
        ),
        hashes.SHA256(),
    )
    return base64.b64encode(signature).decode("utf-8")
