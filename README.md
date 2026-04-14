# Terraform AWS Nginx + ALB (HTTPS)

## 📌 概要

Terraformを用いてAWS上にWebインフラを構築しました。
ALB（Application Load Balancer）を使用し、HTTPS通信を実現しています。

---

## 🏗 構成

* EC2 (nginx)
* ALB (Application Load Balancer)
* ACM (SSL証明書)
* Route53 (独自ドメイン)

---

## 🌐 アーキテクチャ

Client → Route53 → ALB (HTTPS) → EC2 (nginx)

---

## ⚙️ 使用技術

* AWS（EC2 / ALB / ACM / Route53）
* Terraform
* nginx

---

## 🚀 セットアップ方法

```bash
terraform init
terraform apply
```

---

## 🔐 セキュリティ

* EC2はALB経由のみアクセス可能
* HTTPS通信（ACM証明書）
* セキュリティグループによる制御

---

## 📚 学んだこと

* Terraformによるインフラ自動化（IaC）
* ALB + HTTPS構成
* AWSネットワーク設計（VPC / サブネット / SG）
* GitHubでの安全なコード管理

---

## 🌍 デモ
  ![image](./images/screenshot_net-4.net.png)
* https://net-4.net
* (普段はAWSの課金を防ぐために起動していません)

---

## 👤 作成者

* GitHub: https://github.com/tclinux
* Qitta: https://qiita.com/tclinux
