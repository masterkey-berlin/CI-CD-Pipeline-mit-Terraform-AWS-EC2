# CI/CD Pipeline: React App auf AWS EC2 mit Terraform & GitHub Actions

Dieses Projekt implementiert eine durchgängige CI/CD-Pipeline, um eine Vite React Anwendung automatisiert zu bauen, die notwendige AWS-Infrastruktur mit Terraform zu provisionieren und die Anwendung auf einer EC2-Instanz bereitzustellen.

## Aufgabe & Ziel

Ziel war die Erstellung eines GitHub Actions Workflows, der folgende Schritte automatisiert:
1.  **CI (Continuous Integration):** Bauen und Testen der React Frontend-Anwendung.
2.  **IaC (Infrastructure as Code):** Automatisierte Bereitstellung der AWS-Infrastruktur (VPC, Subnetz, Security Group, EC2-Instanz, SSH Key Pair) mittels Terraform. Der Terraform State wird sicher in einem S3 Bucket mit DynamoDB Locking gespeichert.
3.  **CD (Continuous Deployment):** Deployment des gebauten Frontend-Artefakts auf die provisionierte EC2-Instanz, wo es von einem Nginx Webserver ausgeliefert wird.

## Workflow-Übersicht (`.github/workflows/deploy-to-ec2.yml`)

Die Pipeline wird durch einen Push auf den `main`-Branch oder manuell via `workflow_dispatch` ausgelöst und besteht aus drei Haupt-Jobs:

1.  **`ci_build`:**
    *   Checkt den Code aus.
    *   Richtet Node.js ein.
    *   Installiert Abhängigkeiten (`npm ci`).
    *   Baut die React-Anwendung (`npm run build`).
    *   Lädt das Build-Artefakt (`frontend/dist/`) für den nächsten Job hoch.
2.  **`infra_provision` (abhängig von `ci_build`):**
    *   Checkt den Code aus.
    *   Authentifiziert sich bei AWS.
    *   Richtet Terraform ein.
    *   Initialisiert Terraform mit S3 Backend-Konfiguration (`terraform init`).
    *   Erstellt einen Ausführungsplan (`terraform plan`).
    *   Wendet den Plan an, um die AWS-Infrastruktur zu erstellen/aktualisieren (`terraform apply -auto-approve`).
    *   Gibt die öffentliche IP der EC2-Instanz als Output weiter.
3.  **`app_deploy` (abhängig von `infra_provision`):**
    *   Lädt das Build-Artefakt herunter.
    *   Richtet den SSH-Agenten mit dem privaten Schlüssel ein.
    *   Kopiert die Build-Artefakte per `scp` auf die EC2-Instanz in das Webserver-Verzeichnis (`/var/www/html/app`).
    *   Lädt Nginx auf der EC2-Instanz neu (`sudo systemctl reload nginx`).
    *   Führt einen einfachen Smoke-Test per `curl` durch.

## Erstellte AWS Ressourcen (via Terraform)

Die Terraform-Konfiguration im Verzeichnis `terraform/` erstellt folgende Hauptressourcen:
*   **VPC:** Ein Virtual Private Cloud für die Netzwerkisolierung.
*   **Öffentliches Subnetz:** Innerhalb der VPC.
*   **Internet Gateway & Route Table:** Um der VPC Internetzugriff zu ermöglichen.
*   **Security Group:** Erlaubt eingehenden Traffic auf Port 80 (HTTP) und Port 22 (SSH).
*   **EC2 Key Pair:** Für den SSH-Zugriff auf die Instanz.
*   **EC2 Instanz:** Eine `t3.micro` (oder ähnlich) Ubuntu-Instanz, die Nginx per `user_data` Skript installiert und konfiguriert, um die React App auszuliefern.

## Ausführung der Pipeline & Testen der Anwendung

1.  **Secrets Konfiguration (einmalig in GitHub Repository Settings -> Secrets and variables -> Actions):**
    *   `AWS_ACCESS_KEY_ID`: Dein IAM User Access Key ID.
    *   `AWS_SECRET_ACCESS_KEY`: Dein IAM User Secret Access Key.
    *   `AWS_REGION`: Deine AWS Region (z.B. `eu-central-1`).
    *   `TF_STATE_BUCKET`: Name deines S3 Buckets für den Terraform State.
    *   `TF_STATE_DYNAMODB_TABLE`: Name deiner DynamoDB Tabelle für State Locking.
    *   `SSH_PRIVATE_KEY`: Der Inhalt deines privaten SSH-Schlüssels für den EC2-Zugriff.
    *   `SSH_PUBLIC_KEY`: Der Inhalt deines öffentlichen SSH-Schlüssels.
    *   `EC2_USER`: Der Standardbenutzer für das verwendete EC2 AMI (z.B. `ubuntu`).
    *(Hinweis: Die tatsächlichen Secret-Werte werden hier nicht gezeigt und sollten niemals in das Repository eingecheckt werden!)*

2.  **Pipeline auslösen:**
    *   Durch einen Push auf den `main`-Branch.
    *   Oder manuell über den "Actions"-Tab im GitHub Repository (Workflow "Deploy React App to AWS EC2" -> "Run workflow").

3.  **Anwendung testen:**
    *   Nach erfolgreichem Pipeline-Durchlauf wird die öffentliche IP-Adresse der EC2-Instanz im Output des `infra_provision`-Jobs angezeigt.
    *   Öffne `http://<EC2_ÖFFENTLICHE_IP>` in deinem Browser, um die deployte React-Anwendung zu sehen.

## Aufräumen der Infrastruktur (Destroy-Workflow)

Ein separater manueller Workflow **"Destroy AWS Infrastructure (Manual)"** (`.github/workflows/destroy-infra.yml`) wurde erstellt, um die von Terraform verwaltete Infrastruktur sicher zu zerstören:

1.  Gehe zum "Actions"-Tab im GitHub Repository.
2.  Wähle den Workflow "Destroy AWS Infrastructure (Manual)".
3.  Klicke auf "Run workflow".
4.  Gib im erscheinenden Feld zur Bestätigung `destroy` ein und starte den Workflow.

**Manuelles Aufräumen nach dem Destroy-Workflow:**
*   Lösche den S3 Bucket für den Terraform State in der AWS Konsole.
*   Lösche die DynamoDB Tabelle für das State Locking in der AWS Konsole.
*   Entferne die GitHub Secrets, wenn das Projekt vollständig abgeschlossen ist.

---
*(Screenshots des Pipeline-Laufs, der AWS-Ressourcen sind Teil der Abgabe und können im Ordner "images" betrachtet werden. 