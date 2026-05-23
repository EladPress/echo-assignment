docker build -t eladpress/echo-assignment-builder:local-test . #This builds the builder image locally.

docker build -t eladpress/echo-assignment-nginx-patched:local-test --build-arg BRANCH_NAME=local-test -f ../Containerfile . ## This builds the final image locally.