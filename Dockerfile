FROM python:3.11.1-slim-buster

WORKDIR /app

COPY requirements.txt ./

RUN apt-get update && \
    pip install -r requirements.txt

COPY . /app

EXPOSE 8080

#Dont run container as Root
USER 64236:64236

CMD [ "python", "main.py" ]