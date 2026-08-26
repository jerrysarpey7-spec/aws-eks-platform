# AWS EKS Kubernetes Platform

## Overview

This project demonstrates how to build and validate an AWS EKS environment using:

- AWS
- Terraform
- Kubernetes
- Helm
- ArgoCD
- Git

## Architecture

Terraform
↓
AWS VPC
↓
Amazon EKS
↓
Managed Node Group
↓
Kubernetes
↓
Helm
↓
Demo Application

## Project Goals

- Provision AWS infrastructure using Terraform
- Deploy an EKS cluster
- Deploy a containerized application using Helm
- Validate Kubernetes health and recovery
- Implement GitOps using ArgoCD
- Document DevOps testing and troubleshooting steps