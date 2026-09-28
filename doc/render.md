# Running Postal on Render

`render.yaml` in the repository root is a Render Blueprint that creates:

| Service         | Render type        | Purpose                                             |
| --------------- | ------------------ | --------------------------------------------------- |
| `postal-mariadb`| Private service + 10 GB disk | MariaDB 11.4 for all Postal data          |
| `postal-web`    | Web service        | Web UI and HTTP API (public HTTPS)                  |
| `postal-smtp`   | Private service    | SMTP server on port 25 (Render private network only)|
| `postal-worker` | Background worker  | Queue processing and outbound delivery              |

All four need paid instances (private services, disks and pre-deploy commands
are not available on the free plan).

## Limitations of Render

- **No public SMTP port.** Render only routes public HTTP(S) traffic. The SMTP
  server is reachable only from other Render services in the same workspace
  and region, at `postal-smtp:25`. Applications hosted elsewhere must use the
  HTTP API (`https://<POSTAL_WEB_HOSTNAME>/api/v1/send/message`).
- **Inbound mail (MX) cannot be received**, for the same reason.
- **Outbound port 25** may be blocked or have poor reputation from Render's
  shared IPs, and you cannot set reverse DNS. For reliable delivery, set
  `POSTAL_SMTP_RELAYS` on `postal-worker` to a relay such as
  `smtp://smtp.your-relay.com:587`.

## Deploying

1. Generate a signing key and base64-encode it:

   ```bash
   openssl genrsa 2048 | base64 -w0
   ```

2. In the Render Dashboard choose **New → Blueprint**, pick this repository
   and fill in the prompted values:

   - `POSTAL_WEB_HOSTNAME` – e.g. `postal-web.onrender.com` or your own domain
   - `POSTAL_SMTP_HOSTNAME` – e.g. `postal.example.com`
   - `POSTAL_SIGNING_KEY_BASE64` – output of step 1

3. After the first deploy, open a shell on `postal-web` and create an admin:

   ```bash
   /opt/postal/app/docker/render-entrypoint.sh postal make-user
   ```

4. Log in at `https://<POSTAL_WEB_HOSTNAME>`, create an organization and a
   mail server, add and verify your sending domain (SPF, DKIM, return path
   DNS records are shown in the UI), then create credentials under
   **Credentials** – one of type **SMTP** and/or **API**.

## Using the SMTP server from your application

For an application running on Render in the same region:

```
SMTP_HOST=postal-smtp
SMTP_PORT=25
SMTP_USERNAME=<any value, e.g. your-org/your-server>
SMTP_PASSWORD=<SMTP credential key from Postal>
SMTP_AUTH=login          # plain also works
SMTP_TLS=false           # STARTTLS is off unless SMTP_SERVER_TLS_ENABLED is set
MAIL_FROM=you@your-verified-domain.com
```

Examples:

```js
// Node.js (nodemailer)
nodemailer.createTransport({
  host: "postal-smtp", port: 25, secure: false, ignoreTLS: true,
  auth: { user: "postal", pass: process.env.POSTAL_SMTP_KEY },
});
```

```ruby
# Rails
config.action_mailer.smtp_settings = {
  address: "postal-smtp", port: 25, authentication: :login,
  user_name: "postal", password: ENV["POSTAL_SMTP_KEY"],
  enable_starttls_auto: false,
}
```

```python
# Django
EMAIL_HOST = "postal-smtp"
EMAIL_PORT = 25
EMAIL_HOST_USER = "postal"
EMAIL_HOST_PASSWORD = os.environ["POSTAL_SMTP_KEY"]
EMAIL_USE_TLS = False
```

## Using the HTTP API from anywhere

```bash
curl -X POST https://<POSTAL_WEB_HOSTNAME>/api/v1/send/message \
  -H "X-Server-API-Key: <API credential key>" \
  -H "Content-Type: application/json" \
  -d '{"to":["someone@example.com"],"from":"you@your-verified-domain.com",
       "subject":"Hello","plain_body":"Sent via Postal on Render"}'
```
