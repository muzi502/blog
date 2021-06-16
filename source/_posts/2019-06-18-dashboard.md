---
title: deploy kubernets dashborad with https
date: 2019-06-18
categories: 技术
slug:
tag:
  - kubernetes
  - k8s
copyright: true
comment: true
---

## 0.踩坑

部署完 kubernets dashborad 后，官方给出的四种访问模式，都很坑😫。

### 1.kubectl proxy

只能通过本机访问，部署在 VPS 上的是无法登录的。

### 2.NodePort

```txt
In case you are trying to expose Dashboard using NodePort on a multi-node cluster, then you have to find out IP of the node on which Dashboard is running to access it. Instead of accessing https://<master-ip>:<nodePort> you should access https://<node-ip>:<nodePort>.
暴漏 node IP 一个端口来访问，同样浏览器会提示证书问题拒绝访问，测试 chrome edge ie 均无法访问，需要自己加个证书才行。下面就讲解用自己的域名签个证书来用。NodePort 是将节点直接暴露在外网的一种方式，只建议在开发环境，单节点的安装方式中使用。
```

### 3.API Server

```txt
In case Kubernetes API server is exposed and accessible from outside you can directly access dashboard at: https://<master-ip>:<apiserver-port>/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

Note: This way of accessing Dashboard is only possible if you choose to install your user certificates in the browser. In example certificates used by kubeconfig file to contact API Server can be used.
```

### 4.Ingress

```txt
Dashboard can be also exposed using Ingress resource. For more information check: https://kubernetes.io/docs/concepts/services-networking/ingress.
```

## 2.使用acme.sh脚本制作证书

acme.sh脚本从 letsencrypt 可以生成免费的证书
[acme](https://github.com/Neilpang/acme.sh)
[wiki](https://github.com/Neilpang/acme.sh/wiki/%E8%AF%B4%E6%98%8E)

1.安装脚本
```cd ~ && curl  https://get.acme.sh | sh && alias acme.sh=~/.acme.sh/acme.sh```
2.配置好 nginx
我的 nginx 在另一台机器上，需要在域名解析那里添加A记录解析到 nginx 服务器上。添加子域名为 k8s，并在 nginx 那里配置好。
这一步一定要做，不然的话无法通过http验证该域名所属。当然也可以选用 dns 的方式来验证，在这里就不赘述了。

```conf
server {
        listen 80;
        listen [::]:80;
        server_name k8s.k8s.li;
        set $base /var/www/k8s;
        root $base/;
}
```

3.生成证书，默认会保存在~/.acme.sh/mydomain.com
acme.sh --issue  -d mydomain.com   --nginx

4.上传证书到 k8s-master 节点
只需要 mydomain.com.cer 和 mydomain.com.key 这两个文件，其中把 mydomain.com.cer 命名为 dashboard.crt ，mydomain.com.key 命名为 dashboard.key 。然后你想办法把这两个文件传到 k8s-master 机器 ~/certs 目录下。

## 3.部署kubernetes-dashboard

1.引用官方的文档😂
Custom certificates have to be stored in a secret named kubernetes-dashboard-certs in kube-system namespace. Assuming that you have dashboard.crt and dashboard.key files stored under $HOME/certs directory, you should create secret with contents of these files:
```kubectl create secret generic kubernetes-dashboard-certs --from-file=$HOME/certs -n kube-system```

2.下载并修改kubernetes-dashboard.yaml文件

```wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/alternative/kubernetes-dashboard.yaml```

在最后添加```type: NodePort```,注意缩进。

```yml
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
```

3.部署启动 kubernetes-dashboard
```kubectl create -f kubernetes-dashboard.yaml```

4.获取 kubernetes-dashboard 的访问端口和IP

```kubectl -n kube-system get svc kubernetes-dashboard```

5.创建授权用户获取 token

```yml
cat > dashboard-adminuser.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
EOF

kubectl apply -f  dashboard-adminuser.yaml
```

```yml
cat > admin-user-role-binding.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF

kubectl apply -f  admin-user-role-binding.yaml
```

获取登录要用到的 token
```kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')```

```kubectl create secret generic kubernetes-dashboard-certs --from-file=certs -n kube-system```
