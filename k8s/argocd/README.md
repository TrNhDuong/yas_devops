# YAS ArgoCD GitOps

Folder này chứa cấu hình ArgoCD để triển khai YAS vào 2 namespace:

- `yas-dev`
- `yas-staging`

## Cấu trúc

```text
k8s/argocd/
├── projects/yas-project.yaml
├── applications/yas-configuration-dev.yaml
├── applications/yas-configuration-staging.yaml
└── applicationsets/
    ├── yas-dev-services.yaml
    └── yas-staging-services.yaml

k8s/environments/
├── dev/*-values.yaml
└── staging/*-values.yaml
```

## Nguyên tắc

- `k8s/charts/` là Helm chart gốc.
- `k8s/environments/` là values riêng cho `dev` và `staging`.
- CI build image và push Docker Hub.
- CI cập nhật `image.tag` trong `k8s/environments/<env>/<service>-values.yaml`.
- ArgoCD phát hiện Git thay đổi và sync vào Kubernetes.

## Apply ArgoCD resources

```bash
kubectl apply -f k8s/argocd/projects/yas-project.yaml
kubectl apply -f k8s/argocd/applications/yas-configuration-dev.yaml
kubectl apply -f k8s/argocd/applications/yas-configuration-staging.yaml
kubectl apply -f k8s/argocd/applicationsets/yas-dev-services.yaml
kubectl apply -f k8s/argocd/applicationsets/yas-staging-services.yaml
```

## Check

```bash
kubectl get appprojects -n argocd
kubectl get applicationsets -n argocd
kubectl get applications -n argocd
kubectl get pods -n yas-dev
kubectl get pods -n yas-staging
```

## Hosts

Thêm vào file hosts của máy client. Thay `<MINIKUBE_IP>` bằng `minikube ip` hoặc IP node/VM.

```text
<MINIKUBE_IP> backoffice-dev.yas.local.com
<MINIKUBE_IP> storefront-dev.yas.local.com
<MINIKUBE_IP> api-dev.yas.local.com
<MINIKUBE_IP> backoffice-staging.yas.local.com
<MINIKUBE_IP> storefront-staging.yas.local.com
<MINIKUBE_IP> api-staging.yas.local.com
```

## Ghi chú

- `backend` và `ui` trong `k8s/charts` là dependency chart, không tạo ArgoCD Application riêng.
- `yas-configuration` được tách thành Application riêng vì nó tạo config/secret dùng chung.
- Các service còn lại được tạo bằng ApplicationSet.
- Docker Hub username trong files đang dùng `nguyenmanhha`. Nếu nhóm dùng username khác, replace toàn bộ `nguyenmanhha/` trong `k8s/environments`.
