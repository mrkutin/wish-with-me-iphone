# Tech Debt

## Open

### 1. Move QR code generation to client-side in PWA and remove from core-api
- **Date**: 2026-02-09
- **Context**: iOS app now generates QR codes client-side using Core Image (`CIQRCodeGenerator`) from the share URL `https://wishwith.me/s/{token}`. The PWA should do the same (e.g. using a JS library like `qrcode`) instead of relying on the server.
- **Action items**:
  - PWA: generate QR codes client-side from the share URL
  - core-api: remove `generate_qr_code()` from `app/routers/share.py`
  - core-api: remove `qr_code_base64` from `ShareLinkResponse` schema
  - core-api: remove `qrcode` and `Pillow` dependencies
