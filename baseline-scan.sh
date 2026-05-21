docker pull nginx:1.25-bookworm
mkdir -p baseline
trivy image nginx:1.25-bookworm > baseline/baseline-trivy.txt
grype nginx:1.25-bookworm > baseline/baseline-grype.txt