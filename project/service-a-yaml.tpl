apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-a-dep
  labels:
    app.kubernetes.io/name: bitcoin-fetcher
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: bitcoin-fetcher
  template:
    metadata:
      labels:
        app.kubernetes.io/name: bitcoin-fetcher
        network-policy: isolated
    spec:
      containers:
      - name: bitcoin-fetcher
        image: "${image_name}" 
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 15
        env:
        - name: BITCOIN_API_INTERVAL
          value: "60"


---
apiVersion: v1
kind: Service
metadata:
  name: service-a
spec:
  selector:
    app.kubernetes.io/name: bitcoin-fetcher
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
