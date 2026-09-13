"""Run only inside GitHub Actions; secrets are never printed or exported."""
import json
import os
import time
import urllib.request
import jwt

key = os.environ["ASC_PRIVATE_KEY"].strip()
if not key.startswith("-----BEGIN"):
    import base64
    key = base64.b64decode(key).decode()
key = key.replace("\\n", "\n")
token = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()), "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})
request = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/apps/6811508379", headers={"Authorization": "Bearer " + token})
with urllib.request.urlopen(request, timeout=30) as response:
    app = json.load(response)["data"]["attributes"]
print(json.dumps({"name": app["name"], "bundleId": app["bundleId"], "sku": app["sku"]}))
with open(os.environ["GITHUB_ENV"], "a") as output:
    output.write("APP_BUNDLE_ID=" + app["bundleId"] + "\n")
key_path = os.path.join(os.environ["RUNNER_TEMP"], "AuthKey_" + os.environ["ASC_KEY_ID"] + ".p8")
with open(key_path, "w") as output: output.write(key)
os.chmod(key_path, 0o600)
with open(os.environ["GITHUB_ENV"], "a") as output: output.write("ASC_KEY_PATH=" + key_path + "\n")
