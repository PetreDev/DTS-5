# Hadoop MapReduce Task Processing System

A distributed data processing system built on Apache Hadoop that performs filtering and aggregation on task management data using MapReduce jobs with queue-based resource management.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Data Processing](#data-processing)
- [Queue Management](#queue-management)
- [MapReduce Jobs](#mapreduce-jobs)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)

## 🎯 Overview

This project implements a distributed MapReduce job processing system using Apache Hadoop 3.4.1. It processes a CSV dataset of task management records, filtering for completed tasks with urgent/high priority and aggregating completion counts by user.

**Key Features:**

- 🏗️ **Distributed Architecture**: 3 DataNodes, ResourceManager, NodeManagers, JobHistory server
- 📊 **Data Processing**: MapReduce jobs using Hadoop Streaming with Python
- 🎛️ **Queue Management**: Capacity Scheduler with production and development queues
- 📈 **Real-time Monitoring**: Web UI interfaces for cluster and job monitoring
- 🔄 **Fault Tolerance**: HDFS replication and YARN resource management

## 🏗️ Architecture

### Cluster Components

```
┌─────────────────┐    ┌─────────────────┐
│   NameNode      │    │  ResourceManager│
│   (HDFS Master) │    │  (YARN Master)  │
│   Port: 9870    │    │   Port: 8088    │
└─────────────────┘    └─────────────────┘
         │                       │
         ├─────────┬─────────────┘
         │         │
    ┌────▼────┐ ┌──▼──┐ ┌────▼────┐
    │DataNode1│ │ RM  │ │DataNode2│
    │Port:9864│ │     │ │Port:9865│
    └─────────┘ └─────┘ └─────────┘
         │                       │
    ┌────▼────┐             ┌────▼────┐
    │NodeMgr1 │             │DataNode3│
    │Port:8042│             │Port:9866│
    └─────────┘             └─────────┘
                                   │
                              ┌────▼────┐
                              │NodeMgr3 │
                              │Port:8044│
                              └─────────┘
```

### Services

- **NameNode**: HDFS master, manages metadata and namespace
- **DataNodes**: Store actual data blocks (3 nodes, replication factor 2)
- **ResourceManager**: YARN master, manages cluster resources
- **NodeManagers**: YARN slaves, run tasks on each node
- **JobHistory**: Tracks completed MapReduce jobs

## 📋 Prerequisites

- Docker and Docker Compose
- At least 4GB RAM available
- 10GB free disk space
- Linux/WSL2 environment (recommended)

## 🚀 Quick Start

### 1. Start the Hadoop Cluster

```bash
# Clone or navigate to the project directory
cd /path/to/task-5

# Start all services
docker-compose up -d

# Wait for services to initialize (2-3 minutes)
docker-compose logs namenode | tail -20
```

### 2. Verify Cluster Health

```bash
# Check service status
docker-compose ps

# Access HDFS NameNode UI
open http://localhost:9870

# Access YARN ResourceManager UI
open http://localhost:8088
```

### 3. Upload Data and Scripts, Then Run Job

```bash
# Upload sample data to HDFS
docker-compose exec namenode hdfs dfs -mkdir -p /data
docker cp data/todos.csv $(docker-compose ps -q namenode):/tmp/
docker-compose exec namenode hdfs dfs -put -f /tmp/todos.csv /data/

# Copy MapReduce scripts to container
docker cp mapper.py $(docker-compose ps -q namenode):/tmp/
docker cp reducer.py $(docker-compose ps -q namenode):/tmp/

# Make scripts executable
docker-compose exec namenode chmod +x /tmp/mapper.py /tmp/reducer.py

# Run MapReduce job
docker-compose exec namenode hadoop jar /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-3.4.1.jar \
  -files /tmp/mapper.py,/tmp/reducer.py \
  -D mapreduce.job.queuename=production \
  -input /data/todos.csv \
  -output /output \
  -mapper mapper.py \
  -reducer reducer.py

# View results
docker-compose exec namenode hdfs dfs -cat /output/part-00000
```

## ⚙️ Configuration

### Hadoop Configuration Files

#### `core-site.xml`

- **fs.defaultFS**: `hdfs://namenode:9000` - Default HDFS filesystem

#### `hdfs-site.xml`

- **dfs.replication**: `2` - Data replication factor
- **dfs.blocksize**: `64MB` - HDFS block size
- **dfs.namenode.name.dir**: `/tmp/hadoop-hadoop/dfs/name` - NameNode data directory
- **dfs.datanode.data.dir**: `/tmp/hadoop-hadoop/dfs/data` - DataNode data directory

#### `yarn-site.xml`

- **yarn.resourcemanager.hostname**: `resourcemanager` - ResourceManager location
- **yarn.nodemanager.resource.memory-mb**: `2048MB` - Memory per NodeManager
- **yarn.nodemanager.resource.cpu-vcores**: `2` - CPU cores per NodeManager

#### `mapred-site.xml`

- **mapreduce.framework.name**: `yarn` - Execution framework
- **mapreduce.map.memory.mb**: `512MB` - Memory per map task
- **mapreduce.reduce.memory.mb**: `1024MB` - Memory per reduce task

### Queue Configuration (`capacity-scheduler.xml`)

```xml
<!-- Production Queue (Active) -->
<property>
  <name>yarn.scheduler.capacity.root.production.capacity</name>
  <value>70</value>
</property>
<property>
  <name>yarn.scheduler.capacity.root.production.state</name>
  <value>RUNNING</value>
</property>

<!-- Development Queue (Stopped) -->
<property>
  <name>yarn.scheduler.capacity.root.development.capacity</name>
  <value>30</value>
</property>
<property>
  <name>yarn.scheduler.capacity.root.development.state</name>
  <value>STOPPED</value>
</property>
```

## 📊 Data Processing

### Input Data Structure

The system processes a CSV file (`todos.csv`) with the following schema:

```csv
id,title,description,completed,priority,created_at,updated_at,user_id
1,"Fix bug in authentication","This task involves...",True,urgent,"2025-02-25 00:02:57","2025-03-06 06:02:57",4
```

**Fields:**

- `id`: Unique task identifier
- `title`: Task title
- `description`: Task description
- `completed`: Boolean (True/False)
- `priority`: Priority level (urgent/high/medium/low)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp
- `user_id`: User identifier

**Dataset Statistics:**

- Total records: 101 (including header)
- Completed tasks: ~40% of total
- Urgent/High priority tasks: ~30% of total

### MapReduce Logic

#### Mapper (`mapper.py`)

```python
# Filters for completed tasks with urgent/high priority
# Emits: user_id<TAB>1
if completed.lower() == 'true' and priority.lower() in ['urgent', 'high']:
    print('%s\t%d' % (user_id, 1))
```

#### Reducer (`reducer.py`)

```python
# Aggregates counts by user_id
# Emits: user_id<TAB>total_count
current_user, current_count = None, 0
# ... aggregation logic ...
print('%s\t%d' % (current_user, current_count))
```

**Job Flow:**

1. **Input**: CSV file split into chunks
2. **Map**: Filter urgent/high priority completed tasks → `(user_id, 1)` pairs
3. **Shuffle**: Group by user_id
4. **Reduce**: Sum counts per user → `(user_id, total_count)`
5. **Output**: Aggregated results

## 🎛️ Queue Management

### Available Queues

| Queue       | Capacity | State   | Purpose              |
| ----------- | -------- | ------- | -------------------- |
| production  | 70%      | RUNNING | Production workloads |
| development | 30%      | STOPPED | Development/testing  |

### Queue Operations

```bash
# Submit job to production queue (active)
hadoop jar ... -D mapreduce.job.queuename=production ...

# Submit job to development queue (will fail - stopped)
hadoop jar ... -D mapreduce.job.queuename=development ...
# Error: Queue root.development is STOPPED

# Change queue state (requires restart)
# Edit capacity-scheduler.xml and restart cluster
```

### Queue Properties

- **Capacity**: Percentage of cluster resources allocated
- **State**: RUNNING or STOPPED
- **Ordering Policy**: fair/fifo scheduling within queue
- **User Limits**: Resource limits per user

## 🏃‍♂️ MapReduce Jobs

### Running Jobs

#### Basic Hadoop Streaming Command

```bash
# First copy your scripts to the container
docker cp mapper.py $(docker-compose ps -q namenode):/tmp/
docker cp reducer.py $(docker-compose ps -q namenode):/tmp/
docker-compose exec namenode chmod +x /tmp/mapper.py /tmp/reducer.py

# Run the job
docker-compose exec namenode hadoop jar \
  /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-3.4.1.jar \
  -files /tmp/mapper.py,/tmp/reducer.py \
  -D mapreduce.job.queuename=production \
  -input /data/input.csv \
  -output /output/job_$(date +%s) \
  -mapper mapper.py \
  -reducer reducer.py
```

#### Parameters

- `-files`: Comma-separated list of files to distribute to nodes (generic option - place first)
- `-input`: HDFS input path
- `-output`: HDFS output path (must not exist)
- `-mapper`: Mapper script basename (when using -files, just the filename)
- `-reducer`: Reducer script basename (when using -files, just the filename)
- `-D mapreduce.job.queuename`: Target queue

**Note**: Generic options like `-files` must be placed before streaming-specific options like `-input`, `-output`, etc. When using `-files`, reference mapper/reducer by basename only.

### Job Monitoring

```bash
# Check job status
docker-compose exec namenode mapred job -list

# Get job details
docker-compose exec namenode mapred job -status <job_id>

# Kill running job
docker-compose exec namenode mapred job -kill <job_id>
```

### Custom MapReduce Scripts

1. **Create mapper.py and reducer.py** in your project root
2. **Make executable locally**: `chmod +x mapper.py reducer.py`
3. **Copy to container**:
   ```bash
   docker cp mapper.py $(docker-compose ps -q namenode):/tmp/
   docker cp reducer.py $(docker-compose ps -q namenode):/tmp/
   ```
4. **Make executable in container**: `docker-compose exec namenode chmod +x /tmp/mapper.py /tmp/reducer.py`
5. **Run job** with appropriate parameters

## 📈 Monitoring

### Web Interfaces

| Service         | URL                    | Purpose                           |
| --------------- | ---------------------- | --------------------------------- |
| NameNode        | http://localhost:9870  | HDFS file browser, cluster health |
| ResourceManager | http://localhost:8088  | Running jobs, cluster resources   |
| JobHistory      | http://localhost:19888 | Completed job history             |

### CLI Monitoring

```bash
# HDFS operations
docker-compose exec namenode hdfs dfs -ls /
docker-compose exec namenode hdfs dfs -df -h
docker-compose exec namenode hdfs dfsadmin -report

# YARN operations
docker-compose exec namenode yarn application -list
docker-compose exec namenode yarn node -list
docker-compose exec namenode yarn queue -status production

# System logs
docker-compose logs namenode
docker-compose logs resourcemanager
```

### Health Checks

```bash
# Check all services
docker-compose ps

# Test HDFS
docker-compose exec namenode hdfs dfs -touchz /test_file
docker-compose exec namenode hdfs dfs -ls /

# Test YARN
docker-compose exec namenode yarn node -list | grep RUNNING
```

## 🔧 Troubleshooting

### Common Issues

#### Job Fails with Queue Error

```
Error: Queue root.development is STOPPED
```

**Solution**: Use an active queue like `production`

#### Out of Memory Error

```
Container killed by YARN for exceeding memory limits
```

**Solution**: Reduce memory requirements or increase YARN memory allocation

#### HDFS Connection Issues

```
Call From namenode to datanode: Connection refused
```

**Solution**: Check if all DataNodes are running: `docker-compose ps`

#### Mapper/Reducer Scripts Not Found

```
File: file:/tmp/mapper.py does not exist.
Streaming Command Failed!
```

**Solution**: Copy the scripts to the namenode container before running the job:

```bash
# Copy scripts to container
docker cp mapper.py $(docker-compose ps -q namenode):/tmp/
docker cp reducer.py $(docker-compose ps -q namenode):/tmp/

# Make executable
docker-compose exec namenode chmod +x /tmp/mapper.py /tmp/reducer.py
```

#### Unrecognized Option: -files

```
ERROR [main] streaming.StreamJob - Unrecognized option: -files
```

**Solution**: `-files` is a generic option and must be placed before streaming-specific options:

```bash
# Correct order:
hadoop jar hadoop-streaming.jar \
  -files /tmp/mapper.py,/tmp/reducer.py \  # Generic options first
  -D mapreduce.job.queuename=production \  # Then streaming options
  -input /data/todos.csv \
  -output /output \
  -mapper mapper.py \  # Use basename when using -files
  -reducer reducer.py
```

#### Cannot Run Program: No Such File or Directory

```
Caused by: java.io.IOException: Cannot run program "/tmp/mapper.py": error=2, No such file or directory
```

**Solution**: When using `-files`, Hadoop distributes files to the working directory of each task. Reference mapper/reducer by basename only:

```bash
# Wrong:
-mapper /tmp/mapper.py

# Correct (when using -files):
-mapper mapper.py
```

#### Permission Denied

```
Permission denied: user=root, access=WRITE
```

**Solution**: Use HDFS superuser or set proper permissions

### Cluster Recovery

```bash
# Stop cluster
docker-compose down

# Clean persistent data (CAUTION: deletes all data)
docker volume rm $(docker volume ls -q | grep task-5)

# Restart cluster
docker-compose up -d
```

### Log Analysis

```bash
# View specific service logs
docker-compose logs namenode | tail -50
docker-compose logs datanode1 | grep ERROR

# Access container for debugging
docker-compose exec namenode bash
```

## 📁 File Structure

```
task-5/
├── docker-compose.yml          # Docker services configuration
├── README.md                   # This documentation
├── init-namenode.sh           # NameNode initialization script
├── mapper.py                  # MapReduce mapper script
├── reducer.py                 # MapReduce reducer script
├── data/
│   └── todos.csv              # Sample task data (101 records)
└── hadoop-config/
    ├── core-site.xml          # Core Hadoop configuration
    ├── hdfs-site.xml          # HDFS configuration
    ├── yarn-site.xml          # YARN configuration
    ├── mapred-site.xml        # MapReduce configuration
    └── capacity-scheduler.xml # Queue configuration
```

### Key Files Explained

- **`docker-compose.yml`**: Defines 8 Hadoop services with proper networking and volumes
- **`init-namenode.sh`**: Formats and starts the NameNode on first run
- **`mapper.py`**: Python script filtering urgent/high priority completed tasks
- **`reducer.py`**: Python script aggregating task counts by user
- **`capacity-scheduler.xml`**: Configures production (70%, RUNNING) and development (30%, STOPPED) queues

### Data Flow

1. **Input**: `data/todos.csv` uploaded to HDFS `/data/`
2. **Processing**: MapReduce job runs on YARN
3. **Output**: Results stored in HDFS `/output/part-00000`
4. **Monitoring**: Web UIs and CLI tools for tracking

## 🚀 Advanced Usage

### Scaling the Cluster

Edit `docker-compose.yml` to add more DataNodes/NodeManagers:

```yaml
datanode4:
  image: apache/hadoop:3.4.1
  # ... similar configuration
```

### Custom Queue Configuration

Modify `capacity-scheduler.xml` and restart services:

```xml
<property>
  <name>yarn.scheduler.capacity.root.urgent.capacity</name>
  <value>20</value>
</property>
```

### Performance Tuning

- **Memory**: Adjust `yarn.nodemanager.resource.memory-mb`
- **CPU**: Modify `yarn.nodemanager.resource.cpu-vcores`
- **Replication**: Change `dfs.replication` for data durability vs. storage
- **Block Size**: Tune `dfs.blocksize` for I/O optimization

---

**Happy Hadoop-ing! 🐘**
