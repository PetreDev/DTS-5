#!/bin/bash

echo "=========================================="
echo "START"
echo "=========================================="
echo

# Step 1: Create a new directory and upload the CSV file
echo "Step 1: Creating directory and uploading CSV file"
echo "--------------------------------------------------"
hdfs dfs -mkdir -p /assignment_data
echo "Created directory: /assignment_data"

hdfs dfs -put /data/todos.csv /assignment_data/
echo "Uploaded todos.csv to /assignment_data/"
echo

# Step 2: Create a new subdirectory and move the uploaded file
echo "Step 2: Creating subdirectory and moving file"
echo "---------------------------------------------"
hdfs dfs -mkdir -p /assignment_data/processed
echo "Created subdirectory: /assignment_data/processed"

hdfs dfs -mv /assignment_data/todos.csv /assignment_data/processed/
echo "Moved todos.csv to /assignment_data/processed/"
echo

# Step 3: List all directories and files
echo "Step 3: Listing directories and files"
echo "-------------------------------------"
echo "Contents of /assignment_data:"
hdfs dfs -ls -R /assignment_data
echo

# Step 4: Read the file contents
echo "Step 4: Reading file contents"
echo "----------------------------"
echo "First 5 lines of todos.csv:"
hdfs dfs -cat /assignment_data/processed/todos.csv | head -5
echo

echo "Last 10 lines of todos.csv:"
hdfs dfs -cat /assignment_data/processed/todos.csv | tail -10
echo

echo "Entire contents of todos.csv:"
echo "============================="
hdfs dfs -cat /assignment_data/processed/todos.csv
echo

# Step 5: Print disk usage
echo "Step 5: Disk usage for uploaded file"
echo "------------------------------------"
hdfs dfs -du -h /assignment_data/processed/todos.csv
echo

# Step 6: Check block size and replication settings
echo "Step 6: Block size and replication settings"
echo "--------------------------------------------"
echo "File block information:"
hdfs fsck /assignment_data/processed/todos.csv -files -blocks -locations
echo

# Step 7: Print cluster status report
echo "Step 7: Hadoop cluster status report"
echo "------------------------------------"
echo "Cluster Report:"
hdfs dfsadmin -report
echo

echo "=========================================="
echo "END"
echo "=========================================="
