BRANCH_NAME=${1:-master}

docker pull nginx:1.25-bookworm
docker pull eladpress/echo-assignment-nginx-patched:${BRANCH_NAME}

mkdir -p scan-results

trivy image nginx:1.25-bookworm > scan-results/baseline-trivy.txt
trivy image --vex vex.openvex.json eladpress/echo-assignment-nginx-patched:${BRANCH_NAME} > scan-results/patched-trivy.txt