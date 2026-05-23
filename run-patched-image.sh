BRANCH_NAME=${1:-master}

docker run -p 80:80 eladpress/echo-assignment-nginx-patched:${BRANCH_NAME} 