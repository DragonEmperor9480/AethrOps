#!/bin/sh


echo "Compiling AethrOps"
go build -o aethrops


echo "Installing AethrOps"
sudo mv aethrops /usr/local/bin/

echo "AethrOps Installed Successfully!"

echo "Run 'aethrops' to Launch it!"
