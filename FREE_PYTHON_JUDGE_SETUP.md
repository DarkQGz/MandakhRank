# MandakhRank — free Python judge (prototype)

## Where it runs

Keep the **Django/Flutter app on Render**. Run `free-python-judge/` on a **separate Ubuntu Linux VM** with Docker. Oracle Cloud Infrastructure **Always Free Ampere A1** is one possible host; signup/identity verification may be required, availability is not guaranteed, and cloud usage outside Always Free allocations can incur charges. Choose only Always Free-eligible resources, confirm quotas, and enable billing alerts. You need an addressable domain or DNS hostname for automatic HTTPS (for example a domain you already own or a free DNS hostname). The judge must never run in the Render Django service or directly on an unsandboxed Python interpreter.

The judge is a **prototype, not a security-audited sandbox**. It runs attacker-controlled Python. Docker restrictions reduce risk but cannot eliminate container escapes, denial of service, or host compromise. Run it on a dedicated, disposable VM with no databases, private keys, or other sensitive apps. Don't open registration to the general public until you have stronger isolation, abuse monitoring, and security review.

## 1. Prepare Ubuntu VM

- Create an Ubuntu VM with an Always Free-eligible configuration (e.g. 1 OCPU / 6 GB RAM Ampere A1, subject to current availability).
- Allow inbound TCP **22** only from your IP, and **80 and 443** from the internet in both cloud security rules and host firewall. **Do not open 8100 or Docker's TCP socket**.
- SSH into the machine. Install Docker Engine using the [official Ubuntu Docker instructions](https://docs.docker.com/engine/install/ubuntu/). Verify `sudo docker version`.
- Install Caddy with the [official Ubuntu installation instructions](https://caddyserver.com/docs/install). Docker and Caddy installation commands change, so use the maintained instructions.

## 2. Install service

Upload/copy the `free-python-judge/` folder from this project to the VM, then:

```bash
sudo mkdir -p /opt/mandakhrank
sudo cp -r free-python-judge /opt/mandakhrank/
sudo chmod -R a+rX /opt/mandakhrank/free-python-judge
sudo docker pull python:3.12-alpine
sudo useradd --system --home /nonexistent --shell /usr/sbin/nologin mandakhjudge
sudo usermod -aG docker mandakhjudge
```

**Note:** Membership in Docker's group effectively grants root privileges on that VM. This is why the VM must be dedicated to the judge. A safer production solution uses a specialized sandbox and an isolation boundary beyond Docker.

Generate a private random token (the token must be at least 32 characters):

```bash
python3 -c 'import secrets; print(secrets.token_hex(32))'
```

Keep that output private, and write it to a root-owned environment file:

```bash
sudo nano /etc/mandakhrank-judge.env
```

File content (replace placeholder):

```env
JUDGE_API_TOKEN=YOUR_GENERATED_SECRET
```

Then:

```bash
sudo chmod 600 /etc/mandakhrank-judge.env
sudo cp /opt/mandakhrank/free-python-judge/mandakhrank-judge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mandakhrank-judge
sudo systemctl status mandakhrank-judge
curl http://127.0.0.1:8100/health
```

Expected health output: `{"status": "ok"}`.

## 3. HTTPS endpoint

Point a DNS name such as `judge.yourdomain.com` at the VM's public IP. Edit the bundled `Caddyfile` to replace `judge.example.com` with that name, then:

```bash
sudo cp /opt/mandakhrank/free-python-judge/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
curl https://judge.yourdomain.com/health
```

Caddy issues an HTTPS certificate automatically when DNS and inbound 80/443 work. Do not use plain HTTP over the public internet; it would expose the shared secret. For extra hardening, restrict 443 to your Render service outbound IP range if your plan offers known stable IPs, add request rate limits, and monitor abnormal traffic.

## 4. Render settings

Open your **existing** Render `mandakhrank-api` service → Environment and change:

| Key | Value |
|---|---|
| `JUDGE0_URL` | `https://judge.yourdomain.com` (your real HTTPS name, no `/submissions`) |
| `JUDGE0_TOKEN` | SAME secret as `JUDGE_API_TOKEN` on your VM |
| `JUDGE0_PYTHON_ID` | `71` |
| `JUDGE0_RAPIDAPI_KEY` | **Remove or leave empty** |

No Django source changes needed. It already sends `X-Auth-Token` and polls Judge0-style `/submissions` endpoints. Keep Gmail configuration as it is. Save Render env vars and redeploy.

## 5. Try the addition problem

Submit this in MandakhRank:

```python
a, b = map(int, input().split())
print(a + b)
```

For input `3 7`, expected output `10`. If the problem's four hidden tests are valid, the verdict should be `Accepted` with `4/4` tests. If it says `Judge Error`, inspect `sudo journalctl -u mandakhrank-judge -n 100 --no-pager` on the VM and Render logs, without publishing your token.

## Notes and limitations

- Only Python 3, Judge0 language ID 71. It supports `POST /submissions?base64_encoded=true&wait=false` and `GET /submissions/{token}?fields=status` used by this MandakhRank project.
- Two concurrent jobs, maximum 12 queued/in-flight, per-run wall timeout approximately 8 seconds, 128 MB per container, networking disabled, read-only root filesystem, rootless *process inside container* (the host Docker daemon remains privileged), output capped in Python to 16 KB.
- Status tokens are held **in RAM**, so a VM restart loses pending results. Do not run more than one server process or you will have inconsistent status maps.
- The implementation returns Runtime Error for exceptions, but does not yet distinguish every original Judge0 verdict or implement all its endpoints. CPU time is indirectly constrained through CPU quota and wall timeout, not a precise two-second CPU meter.
- The `server.py` implementation uses subprocess capture from Docker. Host-side output is not independently bounded in all failure cases. Do not expose the service to adversarial/public student traffic until this is hardened with stronger sandboxing and output/CPU enforcement.
- The VM must be online for judging to work. This is **no API fee**, not a guarantee of zero cloud charges. Watch Oracle Always Free resource eligibility and account usage.
- Test with `cd free-python-judge && python3 -m unittest -v test_server.py`. These are **mock-based tests**; also run an end-to-end Docker submission on the VM before trusting live results.
