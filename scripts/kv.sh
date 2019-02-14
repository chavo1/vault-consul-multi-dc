#!/usr/bin/env bash

HOST=$(hostname)
# API add value
curl -k \
    --request PUT \
    --data '<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx from '$HOST'!</h1>
</body>
</html>' \
    https://127.0.0.1:8501/v1/kv/$HOST/nginx




   