# Tzibbur API — Usage Guide

A practical guide to sending messages to a [tzibbur.me](https://tzibbur.me) group via the official REST API, with working examples.

---

## 📖 About This Document

This README is a usage-focused companion to the [official Tzibbur API reference](https://github.com/TripleU613/UnTzibburBot/blob/main/docs/tzibbur-api.md). It covers the endpoints, request shapes, error handling, and working examples that were verified against the live API — including the exact JSON schema the server enforces.

---

## 🙏 Credits

| Contribution | Credit |
| :--- | :--- |
| **API documentation** — the official spec, endpoint definitions, auth scheme, and error taxonomy | [**TripleU**](https://github.com/TripleU613) — [official docs](https://github.com/TripleU613/UnTzibburBot/blob/main/docs/tzibbur-api.md) |
| **Token generator** — the tool used to mint the access tokens used in these examples | [**yitz890**](https://github.com/yitz890) |

> All endpoint behavior, request contracts, and error schemas originate from TripleU's [official documentation](https://github.com/TripleU613/UnTzibburBot/blob/main/docs/tzibbur-api.md). The token generator is maintained by [yitz890](https://github.com/yitz890).

---

## 🔐 Authentication

All requests require a bearer token in the `Authorization` header:

```http
Authorization: Bearer <YOUR_ACCESS_TOKEN>
```

Tokens are generated with the token generator credited above (maintained by [yitz890](https://github.com/yitz890)). Treat them as secrets — anyone holding a token can post to the group as your account.

> ⏳ **Tokens expire.** Tzibbur access tokens are time-limited and will eventually stop working. When a token expires, every request will fail with `401 Unauthorized`. There is no refresh flow — you must **regenerate** a new token using the token generator and update wherever it is stored (environment variable, Script Properties, secrets manager, etc.). If you're building an integration, plan for this: catch `401`s, alert yourself, and rotate the token manually.

### Storage recommendations

- **Google Apps Script** → `PropertiesService.getScriptProperties().getProperty('TZIBBUR_TOKEN')`
- **Shell / CI** → environment variable (`TZIBBUR_TOKEN`)
- **Never** commit tokens to source control.

---

## 🌐 Base URL

```text
https://api.tzibbur.me/v1
```

---

## ✉️ Send a Message

### Endpoint

```http
POST /v1/groups/{groupId}/messages
```

### Path parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `groupId` | string (UUID) | The group's ID, taken from the group URL: `https://tzibbur.me/chat/groups/<groupId>` |

### Request headers

| Header | Value |
| :--- | :--- |
| `Authorization` | `Bearer <YOUR_ACCESS_TOKEN>` |
| `Content-Type` | `application/json` |

### Request body

The API requires a **JSON object** containing **both** fields:

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `body` | string | ✅ | The message text. The server automatically prefixes it with the sender's display name (e.g. `Yitz: `), so do **not** include your name yourself. |
| `clientMessageId` | string (UUID v4) | ✅ | Idempotency key. Must be a unique string per logical message. Reuse the *same* value when retrying a failed send. |

> ⚠️ **Common pitfalls**
> - Sending a raw string instead of an object → `expected object, received string` at path `/`.
> - Using `text` instead of `body` → `expected string, received undefined` at path `/body`.
> - Omitting `clientMessageId` → `expected string, received undefined` at path `/clientMessageId`.

### Example request

```bash
curl -X POST \
  'https://api.tzibbur.me/v1/groups/01a13660-4b00-728d-bf59-00accabb4f18/messages' \
  -H "Authorization: Bearer $TZIBBUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
        "body": "Hello from the API!",
        "clientMessageId": "'"$(uuidgen | tr '[:upper:]' '[:lower:]')"'"
      }'
```

### Example response — `201 Created`

```json
{
  "message": {
    "id": "01a184b0-3f80-76ba-b693-d89db2a8ce23",
    "groupId": "01a13660-4b00-728d-bf59-00accabb4f18",
    "seq": 757,
    "senderId": "01a08168-2829-746b-bb1d-61c95e4d908f",
    "body": "Yitz: Hello from Google Apps Script!",
    "clientMessageId": "88328743-9037-4037-9119-0d9172c8c6e3",
    "createdAt": "2026-10-28T22:45:05.536Z"
  },
  "duplicate": false
}
```

| Field | Meaning |
| :--- | :--- |
| `id` | Server-assigned message ID |
| `groupId` | Group the message landed in |
| `seq` | Monotonic sequence number within the group |
| `senderId` | Account the token belongs to |
| `body` | Stored text, including the server-added sender prefix |
| `clientMessageId` | Echo of the idempotency key you supplied |
| `createdAt` | ISO-8601 UTC timestamp |
| `duplicate` | `false` for a fresh send; `true` if the same `clientMessageId` was already used |

### Example response — `200 OK`

A `200` indicates either an **idempotent duplicate** (the same `clientMessageId` was reused) or a response to an **in-chat command**. Inspect the `duplicate` flag to distinguish them.

---

## 🔁 Idempotent Retries

The `clientMessageId` exists so that network failures don't result in duplicate posts. The correct retry pattern is:

1. Generate a UUID **once** per logical message.
2. Attempt the `POST`.
3. On a transient failure (timeout, `5xx`), retry with the **same** `clientMessageId`.
4. The server returns the original message with `"duplicate": true` instead of posting twice.

Never generate a new UUID for a retry — that defeats the purpose and will create a duplicate message.

---

## ⚠️ Error Reference

All errors return a structured JSON body:

```json
{
  "type": "urn:tzibbur:error:validation_failed",
  "title": "validation_failed",
  "status": 400,
  "detail": "Request validation failed",
  "requestId": "01a184af-8ecc-76bf-b74e-613cff7fae97",
  "errors": [
    {
      "path": "/clientMessageId",
      "message": "Invalid input: expected string, received undefined",
      "code": "invalid_type"
    }
  ]
}
```

| Status | Title | Typical cause | Fix |
| :--- | :--- | :--- | :--- |
| `400` | `validation_failed` | Missing/mistyped field | Read `errors[].path` — it names the offending field |
| `401` | `unauthorized` | Token missing, expired, or invalid | **Regenerate the token** via the token generator |
| `403` | `forbidden` | Token lacks access to the group | Confirm group membership |
| `404` | `not_found` | Bad `groupId` | Re-copy the ID from the group URL |
| `409` | `conflict` | Duplicate on a non-idempotent path | Usually returns `200` with `duplicate: true` instead |
| `429` | `rate_limited` | Too many requests | Back off and retry with the same `clientMessageId` |
| `5xx` | — | Server-side failure | Retry with the same `clientMessageId` |

The `requestId` field is invaluable when reporting issues — include it with any bug report.

---

## 🧩 Google Apps Script Example

A ready-to-paste `Code.gs` for sending a message from a Google Sheet, Form, or time-driven trigger:

```javascript
function sendTzibburGroupMessage() {
  // Read the token from Script Properties (Project Settings → Script Properties).
  // When the token expires, update this property with a freshly generated token.
  const ACCESS_TOKEN = PropertiesService.getScriptProperties().getProperty('TZIBBUR_TOKEN');

  const GROUP_ID     = '01a13660-4b00-728d-bf59-00accabb4f18';
  const MESSAGE_TEXT = 'Hello from Google Apps Script!';

  const url = `https://api.tzibbur.me/v1/groups/${GROUP_ID}/messages`;

  const payload = {
    body: MESSAGE_TEXT,
    clientMessageId: Utilities.getUuid()
  };

  const options = {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {
    const response = UrlFetchApp.fetch(url, options);
    const code = response.getResponseCode();
    const text = response.getContentText();

    if (code === 201) {
      Logger.log('✅ Sent: ' + text);
    } else if (code === 200) {
      Logger.log('ℹ️ Accepted (duplicate or command): ' + text);
    } else if (code === 401) {
      Logger.log('🔑 Token expired or invalid — regenerate via the token generator and update Script Properties.');
    } else {
      Logger.log(`❌ Failed ${code}: ${text}`);
    }
  } catch (e) {
    Logger.log('❌ Exception: ' + e);
  }
}
```

---

## 💻 Node.js Example

```javascript
import { randomUUID } from 'node:crypto';

// Token can expire — regenerate via the token generator and update the env var.
const ACCESS_TOKEN = process.env.TZIBBUR_TOKEN;
const GROUP_ID     = '01a13660-4b00-728d-bf59-00accabb4f18';

async function sendMessage(body) {
  const clientMessageId = randomUUID();

  const res = await fetch(
    `https://api.tzibbur.me/v1/groups/${GROUP_ID}/messages`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ body, clientMessageId })
    }
  );

  const data = await res.json();

  if (res.status === 201) {
    console.log('✅ Sent, seq =', data.message.seq);
  } else if (res.status === 200) {
    console.log('ℹ️ Duplicate detected:', data.duplicate);
  } else if (res.status === 401) {
    console.error('🔑 Token expired or invalid — regenerate via the token generator.');
  } else {
    console.error('❌', res.status, data);
  }

  return data;
}

sendMessage('Hello from Node!');
```

---

## 🔗 References

- **TripleU on GitHub** — [@TripleU613](https://github.com/TripleU613)
- **Official Tzibbur API documentation** — [TripleU613/UnTzibburBot → docs/tzibbur-api.md](https://github.com/TripleU613/UnTzibburBot/blob/main/docs/tzibbur-api.md)
- **Token generator** — [@yitz890](https://github.com/yitz890)
- **Tzibbur web app** — <https://tzibbur.me>

---

## 📝 License

This README is provided as-is for community use. The API itself, its documentation, and the Tzibbur service are the work of their respective authors — please direct credit for those to [**TripleU**](https://github.com/TripleU613). The token generator is the work of [**yitz890**](https://github.com/yitz890).
