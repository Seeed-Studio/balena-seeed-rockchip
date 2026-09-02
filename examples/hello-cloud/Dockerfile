FROM arm64v8/alpine:3.20

# balenaCloud E2E demo: 每 10s 打一条带云注入环境变量的日志，
# dashboard 的 Logs 面板应持续滚动显示。
CMD ["sh", "-c", "echo \"hello-cloud started on $(hostname)\"; while true; do echo \"[$(date '+%H:%M:%S')] device=${BALENA_DEVICE_NAME_AT_INIT:-?} fleet=${BALENA_APP_NAME:-?} arch=$(uname -m)\"; sleep 10; done"]
