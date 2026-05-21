
mkdir -p post
trivy image post > post/post-trivy.txt
grype post > post/post-grype.txt