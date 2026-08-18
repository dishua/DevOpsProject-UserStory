# Vagrant Infrastructure for DevOpsProject-UserStory

This directory contains the complete multi-node **Vagrant** configuration and provisioning shell scripts for deploying the 3-tier [DevOpsProject-UserStory](https://github.com/dishua/DevOpsProject-UserStory/tree/master) application in an isolated local virtual environment.

The environment provisions three lightweight **Alpine Linux 3.19** VirtualBox virtual machines representing the Database, Backend, and Frontend layers.

---

## 📁 Directory Structure

```text
Vagrant/
├── Vagrantfile
└── scripts/
    ├── setup-backend.sh
    ├── setup-db.sh
    └── setup-frontend.sh
```

---

## 🏗️ Architecture & Node Specifications

The architecture separates concerns into three distinct virtual machines configured via a private network (`192.168.56.0/24` subnet):

| VM Name | Hostname | IP Address | Guest OS | Resources | Installed Services / Tech Stack |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `db` | `db` | `192.168.56.10` | Alpine 3.19 (`generic/alpine319`) | 1 vCPU, 1024 MB RAM | **MariaDB** (Database Server) |
| `backend` | `backend` | `192.168.56.11` | Alpine 3.19 (`generic/alpine319`) | 1 vCPU, 1024 MB RAM | **Java 17 (OpenJDK)**, **Maven**, **Spring Boot App** (OpenRC service on port `8080`) |
| `frontend` | `frontend` | `192.168.56.12` | Alpine 3.19 (`generic/alpine319`) | 1 vCPU, 1024 MB RAM | **Node.js**, **NPM**, **Nginx** (Reverse Proxy on port `80`) |

### Network & Port Mapping
* **Private Network Subnet:** `192.168.56.X`
* **Host Port Forwarding:** Frontend HTTP (Guest Port `80`) is mapped to Host Port `3000` (`http://localhost:3000`).
* **Frontend-to-Backend Proxy:** Nginx routes `/api/` requests from the frontend VM directly to the backend service at `http://192.168.56.11:8080/`.
* **Backend-to-Database Connection:** The backend service connects to MariaDB via JDBC at `jdbc:mariadb://192.168.56.10:3306/userstoryproj`.

---

## ⚙️ Prerequisites

Before launching the virtual machines, ensure you have the following installed on your host machine:

1. [VirtualBox](https://www.virtualbox.org/) (v7.0 or higher recommended)
2. [Vagrant](https://developer.hashicorp.com/vagrant/downloads) (v2.3+ recommended)
3. Git

---

## 🔑 Environment Configuration (`.env`)

The `Vagrantfile` automatically looks for environment configuration in the parent directory under `../config/.env`. **This file must exist before running `vagrant up`**.

### Required Environment Variables
Create or verify `../config/.env` with the following variables:

```env
# Database Credentials
DB_ROOT_PASSWORD=your_root_password_here
DB_USERSTORYPROJ_USER=userstory_db_user
DB_USERSTORYPROJ_PASSWORD=userstory_db_password
```

> **Note:** The `Vagrantfile` reads `.env`, parses the key-value pairs, and securely injects only the relevant credentials into each virtual machine during provisioning.

---

## 🚀 Quick Start Guide

### 1. Clone the Repository & Navigate to the Vagrant Directory
```bash
git clone [https://github.com/dishua/DevOpsProject-UserStory.git](https://github.com/dishua/DevOpsProject-UserStory.git)
cd DevOpsProject-UserStory/Vagrant
```

### 2. Ensure `.env` File Exists
Ensure `../config/.env` is configured properly relative to the `Vagrant/` folder.

### 3. Spin Up the Virtual Machines
Run the following command to create and provision all three virtual machines (`db`, `backend`, and `frontend`):

```bash
vagrant up
```

*Vagrant will sequentially boot the VMs and execute the respective setup shell scripts.*

### 4. Access the Application
Once provisioning completes, access the application in your browser:
* **Host Machine:** `http://localhost:3000`
* **Direct Private IP:** `http://192.168.56.12`

---

## 📜 Provisioning Scripts Detail

### 1. `scripts/setup-db.sh` (`db` VM)
* Installs MariaDB server and client package (`mariadb mariadb-client`).
* Updates `/etc/my.cnf.d/mariadb-server.cnf` to bind to `0.0.0.0` for remote private network access.
* Initializes the database storage directory if not already initialized.
* Enables and starts MariaDB under Alpine's **OpenRC** init system.
* Creates the database `userstoryproj`, sets the `root` password, and creates the application user (`DB_USERSTORYPROJ_USER`) with full privileges on `userstoryproj.*`.

### 2. `scripts/setup-backend.sh` (`backend` VM)
* Validates required environment variables (`DB_IP`, `DB_USERSTORYPROJ_USER`, `DB_USERSTORYPROJ_PASSWORD`).
* Installs OpenJDK 17, Maven, and Git via `apk`.
* Performs a sparse clone of the `master` branch of `https://github.com/dishua/DevOpsProject-UserStory.git` to extract only the `backend/` folder.
* Builds the Spring Boot application using `mvn clean package -DskipTests`.
* Deploys the generated executable JAR file to `/opt/backend/app.jar`.
* Configures OpenRC environment variables (`/etc/conf.d/backend`) with the MariaDB JDBC connection string `jdbc:mariadb://${DB_IP}:3306/userstoryproj`.
* Registers and starts the OpenRC service `/etc/init.d/backend`, logging output to `/var/log/backend.log`.

### 3. `scripts/setup-frontend.sh` (`frontend` VM)
* Validates the `BACKEND_IP` environment variable.
* Sets `REACT_APP_BACKEND_URL="http://${BACKEND_IP}:8080"`.
* Installs Nginx, Node.js, NPM, and Git via `apk`.
* Sparse-clones the `frontend/` directory from the repository.
* Installs dependencies (`npm ci` / `npm install`) and builds static assets.
* Deploys static build artifacts to `/var/www/html/`.
* Configures Nginx (`/etc/nginx/http.d/default.conf`) to:
  * Serve the React static build with single-page app routing (`try_files $uri$uri/ /index.html`).
  * Proxy API calls (`/api/`) directly to `http://${BACKEND_IP}:8080/`.
* Validates Nginx configuration and starts the Nginx service via OpenRC.

---

## 🛠️ Useful Vagrant Commands

| Task | Command |
| :--- | :--- |
| **Start all VMs** | `vagrant up` |
| **Start specific VM** | `vagrant up db` / `vagrant up backend` / `vagrant up frontend` |
| **Check VM status** | `vagrant status` |
| **SSH into a VM** | `vagrant ssh db` / `vagrant ssh backend` / `vagrant ssh frontend` |
| **Reprovision a VM** | `vagrant provision backend` |
| **Reload VM with new Vagrantfile config** | `vagrant reload` |
| **Stop all VMs** | `vagrant halt` |
| **Destroy all VMs** | `vagrant destroy -f` |

---

## 🔍 Troubleshooting & Verification

### Check OpenRC Service Status inside VMs
SSH into any VM and check the status of installed services:

```bash
# On db VM
vagrant ssh db
sudo rc-service mariadb status

# On backend VM
vagrant ssh backend
sudo rc-service backend status
tail -f /var/log/backend.log

# On frontend VM
vagrant ssh frontend
sudo rc-service nginx status
sudo nginx -t
```

### Test Network Connectivity Between VMs
```bash
# Test MariaDB connectivity from Backend VM
vagrant ssh backend
nc -zv 192.168.56.10 3306

# Test Backend API connectivity from Frontend VM
vagrant ssh frontend
curl -I [http://192.168.56.11:8080/](http://192.168.56.11:8080/)
```