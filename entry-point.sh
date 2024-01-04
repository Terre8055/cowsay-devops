#!/bin/sh

if [ "$#" -ne 1 ]
then
  PORT=8080
else
  PORT=$1
fi

export PORT=$PORT
npm start