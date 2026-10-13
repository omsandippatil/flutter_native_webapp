# TapApp

TapApp is a Flutter learning application backed by a Cloudflare Worker and a Frappe learning platform.

## Quick start

```bash
flutter pub get
flutter run -d chrome
```

Worker development:

```bash
cd worker
npm ci
npm run dev
```

## Documentation

Complete frontend, Worker, Frappe, API, content, deployment, and operations documentation is in [`documentation/`](documentation/index.md).

Serve it locally with MkDocs Material:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r documentation/requirements.txt
mkdocs serve
```
