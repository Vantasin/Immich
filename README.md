# 📸 Immich Docker Compose Stack

[![MIT License](https://img.shields.io/github/license/Vantasin/Immich?style=flat-square)](LICENSE)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)](https://www.docker.com/)
[![ZFS](https://img.shields.io/badge/ZFS-OpenZFS-blue?style=flat-square)](https://openzfs.org/)

[![Powered by Immich](https://img.shields.io/badge/Powered%20by-Immich-5562EA?logo=immich&logoColor=white&style=flat-square)](https://github.com/immich-app/immich)

Immich is a high-performance, self-hosted photo and video backup solution built with modern technologies like TypeScript, NestJS, and Flutter. It offers automatic mobile uploads, real-time AI-based face and object recognition, and powerful search capabilities — all under your control.

---

## 📁 Directory Structure

```bash
tank/
├── docker/
│   ├── compose/
│   │   └── immich/              # Git repo lives here
│   │       ├── docker-compose.yml  # Main Docker Compose config
│   │       ├── .env                # Runtime environment variables and secrets (gitignored!)
│   │       ├── env.example         # Example .env file for reference
│   │       ├── immich_restore.sh   # Safely restores Immich data from a backup using directory paths loaded from the .env file.
│   │       └── README.md           # This file
│   └── data/
│       └── immich/              # Volume mounts and persistent data
```

---

## 🧰 Prerequisites

* Docker Engine
* Docker Compose V2
* Git
* (Optional) ZFS on Linux for dataset management

> ⚠️ **Note:** These instructions assume your ZFS pool is named `tank`. If your pool has a different name (e.g., `rpool`, `zdata`, etc.), replace `tank` in all paths and commands with your actual pool name.

---

## ⚙️ Setup Instructions

1. **Create the stack directory and clone the repository**

   If using ZFS:
   ```bash
   sudo zfs create -p tank/docker/compose/immich
   cd /tank/docker/compose/immich
   sudo git clone https://github.com/Vantasin/Immich.git .
   ```

   If using standard directories:
   ```bash
   mkdir -p ~/docker/compose/immich
   cd ~/docker/compose/immich
   git clone https://github.com/Vantasin/Immich.git .
   ```

2. **Create the runtime data directory** (optional)

   If using ZFS:
   ```bash
   sudo zfs create -p tank/docker/data/immich
   ```

   If using standard directories:
   ```bash
   mkdir -p ~/docker/data/immich
   ```

3. **Configure environment variables**

   Copy and modify the `.env` file:

   ```bash
   sudo cp env.example .env
   sudo nano .env
   sudo chmod 600 .env
   ```

   > **Note:** Be sure to update the `DB_PASSWORD` and if necessary the `UPLOAD_LOCATION` & `DB_DATA_LOCATION`.
      
   > **Tip:** You can create a URL `https://immich.example.com` using [Nginx Proxy Manager](https://github.com/Vantasin/Nginx-Proxy-Manager.git) as a reverse proxy for HTTPS certificates via Let's Encrypt.

5. **Start immich**

   ```bash
   sudo docker compose up -d
   ```

---

## 🌐 Accessing Immich Web UI

Once deployed, access **Immich** using:

- **Web Interface:** Enter the URL for Immich. Eg. `https://immich.example.com` or `http://localhost:2283`.

- **Initial Setup:** When you first access the web interface, you will be prompted to create a superuser account.

- **Optional:** Download the mobile app to easily sync your phone's camera roll.

---

## 🙏 Acknowledgments

- [ChatGPT](https://openai.com/chatgpt) — for assistance in generating setup scripts and templates.
- [Docker](https://www.docker.com/) — for container orchestration and runtime.
- [OpenZFS](https://openzfs.org/) — for advanced local filesystem features, dataset organization, and snapshotting.
- [Immich](https://github.com/immich-app/immich) — a modern, high-performance, self-hosted photo and video backup solution with AI-powered search, face recognition, and mobile apps.
