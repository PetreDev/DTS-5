#!/bin/bash

# Initialize NameNode
echo "Initializing NameNode..."

# Format the NameNode if not already formatted
if [ ! -d "/tmp/hadoop-hadoop/dfs/name/current" ]; then
    echo "Formatting NameNode..."
    hdfs namenode -format -force -nonInteractive
fi

# Start NameNode
echo "Starting NameNode..."
hdfs namenode
