
mkdir -p post
trivy image post --vex vex.openvex.json > post/post-trivy.txt
# grype post --vex vex.json > post/post-grype.txt