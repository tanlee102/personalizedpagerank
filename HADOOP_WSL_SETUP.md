# Hướng dẫn cài đặt Hadoop trên Windows Subsystem for Linux (WSL)

## 1. Cài đặt JDK 8

```bash
sudo apt update
sudo apt install openjdk-8-jdk
```

- **Kiểm tra đường dẫn JAVA_HOME:**
  ```bash
  readlink -f $(which java)
  # Thường là /usr/lib/jvm/java-8-openjdk-amd64/bin/java
  ```
- **Khuyến nghị:** Dùng JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 cho Ubuntu trên WSL.

## 2. Tải và giải nén Hadoop

```bash
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
```

## 3. Thiết lập biến môi trường

Thêm vào cuối file `~/.bashrc`:

```bash
export USER_HOME="/user/$(whoami)"

# ============================================
# Hadoop & Java environment variables
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HADOOP_HOME=$HOME/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME

# Thêm Hadoop vào PATH để có thể gõ lệnh 'hadoop' ở bất kỳ đâu
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
# ============================================
```

Sau đó:

```bash
source ~/.bashrc
```

## 4. Kiểm tra biến môi trường

```bash
echo $JAVA_HOME
echo $HADOOP_HOME
hadoop version
```

## 5. Thiết lập SSH không mật khẩu

```bash
sudo apt install openssh-server
sudo service ssh start
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ssh localhost   # Đảm bảo không hỏi mật khẩu
```

- **Kiểm tra trạng thái SSH:**
  ```bash
  sudo service ssh status
  ```

## 6. Cấu hình Hadoop ở chế độ Pseudodistributed

### core-site.xml

Mở file `$HADOOP_HOME/etc/hadoop/core-site.xml` và chỉnh như sau:

```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/home/${user.name}/hadoop_tmp</value>
  </property>
</configuration>
```

### hdfs-site.xml

Mở file `$HADOOP_HOME/etc/hadoop/hdfs-site.xml` và chỉnh như sau:

```xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///home/${user.name}/hadoop_tmp/dfs/name</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///home/${user.name}/hadoop_tmp/dfs/data</value>
  </property>
</configuration>
```

### mapred-site.xml

Mở file `$HADOOP_HOME/etc/hadoop/mapred-site.xml` và chỉnh như sau:

```xml
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.env</name>
    <value>HADOOP_MAPRED_HOME=/home/$(whoami)/hadoop</value>
  </property>
  <property>
    <name>mapreduce.map.env</name>
    <value>HADOOP_MAPRED_HOME=/home/$(whoami)/hadoop</value>
  </property>
  <property>
    <name>mapreduce.reduce.env</name>
    <value>HADOOP_MAPRED_HOME=/home/$(whoami)/hadoop</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>1024</value>
  </property>
  <property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.map.cpu.vcores</name>
    <value>1</value>
  </property>
  <property>
    <name>mapreduce.reduce.cpu.vcores</name>
    <value>1</value>
  </property>
</configuration>
```

### yarn-site.xml

Mở file `$HADOOP_HOME/etc/hadoop/yarn-site.xml` và chỉnh như sau:

```xml
<configuration>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>localhost</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>3072</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>2</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>1024</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-vcores</name>
    <value>1</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
```

### hadoop-env.sh

Mở file `$HADOOP_HOME/etc/hadoop/hadoop-env.sh` và thêm hoặc sửa:

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

export HADOOP_NAMENODE_OPTS="-Xms512m -Xmx1024m $HADOOP_NAMENODE_OPTS"
export HADOOP_DATANODE_OPTS="-Xms512m -Xmx1024m $HADOOP_DATANODE_OPTS"
export HADOOP_SECONDARYNAMENODE_OPTS="-Xms512m -Xmx1024m $HADOOP_SECONDARYNAMENODE_OPTS"
export YARN_RESOURCEMANAGER_OPTS="-Xms512m -Xmx1024m $YARN_RESOURCEMANAGER_OPTS"
export YARN_NODEMANAGER_OPTS="-Xms512m -Xmx1024m $YARN_NODEMANAGER_OPTS"
```

## 7. Khởi tạo HDFS

```bash
mkdir -p ~/hadoop_tmp/dfs/name
mkdir -p ~/hadoop_tmp/dfs/data
hdfs namenode -format
```

## 8. Khởi động và dừng Hadoop

- **Khởi động:**
  ```bash
  start-dfs.sh
  start-yarn.sh
  ```
- **Dừng:**
  ```bash
  stop-yarn.sh
  stop-dfs.sh
  ```
- **Kiểm tra trạng thái các dịch vụ:**
  ```bash
  jps
  # Kỳ vọng thấy: NameNode, DataNode, ResourceManager, NodeManager, SecondaryNameNode
  ```

## 9. Upload file lên HDFS

- **Tạo file input.txt mẫu:**
  ```bash
  echo -e "hello world\nhello hadoop\nhello wsl" > ~/input.txt
  ```
- **Upload lên HDFS:**
  ```bash
  hdfs dfs -mkdir -p /user/$(whoami)/input
  hdfs dfs -put ~/input.txt /user/$(whoami)/input/
  hdfs dfs -ls /user/$(whoami)/input/
  ```

## 10. Chạy thử WordCount

- **Chạy ví dụ WordCount:**
  ```bash
  hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar wordcount /user/$(whoami)/input /user/$(whoami)/output
  ```
- **Xem kết quả:**
  ```bash
  hdfs dfs -cat /user/$(whoami)/output/part-*
  ```

## 11. Lưu ý khi dùng WSL

- **Quyền truy cập file/folder:**
  - Nên thao tác file trong thư mục home của WSL (`/home/yourname`), tránh dùng trực tiếp file từ `/mnt/c/...` để tránh lỗi quyền.
- **JAVA_HOME:**
  - Nếu bạn cài JDK ở vị trí khác, hãy sửa lại biến JAVA_HOME và trong `hadoop-env.sh` cho đúng.
- **Nếu gặp lỗi:**
  - Kiểm tra lại quyền file, trạng thái SSH, trạng thái các tiến trình Hadoop bằng `jps`.
- **Dùng Ubuntu 20.04 hoặc 22.04 trên WSL để đảm bảo tương thích tốt nhất.** 