# FormBridge Local Demo - Quick Reference Card

## 🚀 Get Started (Copy-Paste These)

### Terminal 1: Start Services
```bash
cd w:\PROJECTS\formbridge
make local-up
```

### Terminal 2: Start API
```bash
cd w:\PROJECTS\formbridge
make sam-api
```

### Terminal 3: Test It
```bash
cd w:\PROJECTS\formbridge
make local-test
```

---

## 🌐 Open These URLs

| What | URL |
|------|-----|
| **Frontend** | http://localhost:8080 |
| **DynamoDB Data** | http://localhost:8001 |
| **Emails Sent** | http://localhost:8025 |

---

## 📝 Manual Test (Copy-Paste)

```bash
curl -X POST http://localhost:3000/submit \
  -H "Content-Type: application/json" \
  -d "{
    \"form_id\": \"my-form\",
    \"name\": \"John Doe\",
    \"email\": \"john@example.com\",
    \"message\": \"This is a test\"
  }"
```

---

## 🛑 Stop Everything

```bash
make local-down
```

---

## 🧹 Clean Up Completely

```bash
make local-clean
```

---

## ❓ All Available Commands

```bash
make help              # Show all commands
make local-up          # Start services
make local-down        # Stop services
make local-ps          # Show containers
make local-logs        # View logs
make local-bootstrap   # Create DB table
make local-test        # Run tests
make sam-api           # Start API
make local-clean       # Remove volumes
```

---

## 🧪 What to Check

After `make local-up && make sam-api`:

1. **API Response** - Check terminal output
   ```
   Should show: {"id": "some-uuid"}
   ```

2. **Database** - Open http://localhost:8001
   ```
   Should see: contact-form-submissions table with data
   ```

3. **Emails** - Open http://localhost:8025
   ```
   Should see: notification email
   ```

---

## ⚡ Common Issues & Fixes

| Problem | Fix |
|---------|-----|
| `make: not found` | Use `docker compose` directly (see local/README.md) |
| Port already in use | `make local-down` then `make local-up` |
| No data in DynamoDB | Run `make local-bootstrap` |
| No emails in MailHog | Check Lambda logs in `make sam-api` output |
| `docker: not found` | Install Docker Desktop |

---

## 📚 Full Documentation

**See these files for complete information:**
- `local/README.md` - 300+ line complete guide
- `Makefile` - All available commands
- `LOCAL_DEMO_COMPLETE.md` - Full implementation guide
- `.azure/local-demo-implementation.md` - Technical details

---

## 💡 Pro Tip

Keep three terminal windows open:

```
Terminal 1:              Terminal 2:              Terminal 3:
make local-logs          make sam-api             curl http://...
(watch all logs)         (keep API running)       (run tests)
```

---

**That's it! You're ready to demo.** 🎉

