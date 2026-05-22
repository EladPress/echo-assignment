FROM python:3.11-slim

WORKDIR /test

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY test_nginx.py .

CMD ["python", "-m", "pytest", "test_nginx.py", "-v"]
