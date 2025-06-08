# Personalized PageRank (PPR) trên Hadoop MapReduce

## 1. Tổng quan & Lý thuyết

**Personalized PageRank (PPR)** là biến thể của thuật toán PageRank, cho phép cá nhân hóa việc xếp hạng các nút trong đồ thị dựa trên một nút nguồn (source) do người dùng chỉ định. Thay vì mỗi lần "teleport" về một nút ngẫu nhiên, PPR luôn teleport về source, giúp đánh giá mức độ liên quan của các nút khác đối với source này.

**Công thức cập nhật PPR:**
- Với mỗi node \( i \):
  - Nếu \( i \) là source:  
    \( PR_{new}(i) = (1-d) + d \times (\text{sumContrib} + \text{danglingSum}) \)
  - Nếu \( i \) khác source:  
    \( PR_{new}(i) = d \times \text{sumContrib} \)
- Trong đó:
  - \( d \): hệ số damping (thường 0.85)
  - sumContrib: tổng đóng góp từ các node trỏ tới \( i \)
  - danglingSum: tổng PageRank từ các node không có outbound link (dangling nodes)

**Ý tưởng cài đặt trên Hadoop MapReduce:**
- **Map:** Phân phối giá trị PageRank hiện tại của mỗi node cho các node lân cận, xử lý dangling node, phát lại adjacency list.
- **Reduce:** Tổng hợp đóng góp, cộng thêm phần teleport về source, cập nhật giá trị PPR cho mỗi node.
- **Lặp ngoài:** Script shell điều khiển số vòng lặp, kiểm tra hội tụ (max delta), gom kết quả cuối.

---

## 2. Cài đặt Hadoop (Pseudodistributed)

### 2.1. Cài đặt JDK 8
- Tải và cài đặt JDK 8 phù hợp với hệ điều hành của bạn.
- Đảm bảo JAVA_HOME trỏ đúng thư mục cài đặt JDK 8 (ví dụ: `/opt/jdk8`).

### 2.2. Tải và giải nén Hadoop
```bash
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
```

### 2.3. Thiết lập biến môi trường
Thêm vào cuối file `~/.bashrc` (hoặc `~/.zshrc` nếu dùng zsh):
```bash
export JAVA_HOME=/opt/jdk8
export PATH=$JAVA_HOME/bin:$PATH
export HADOOP_HOME=$HOME/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```
Sau đó:
```bash
source ~/.bashrc
```
Kiểm tra:
```bash
echo $JAVA_HOME
echo $HADOOP_HOME
hadoop version
```

### 2.4. Thiết lập SSH không mật khẩu
```bash
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ssh localhost   # Đảm bảo không hỏi mật khẩu
```

### 2.5. Cấu hình Hadoop (Pseudodistributed)
- Sửa các file cấu hình trong `$HADOOP_HOME/etc/hadoop/` như sau:

#### core-site.xml
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

#### hdfs-site.xml
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

#### mapred-site.xml
```xml
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.env</name>
    <value>HADOOP_MAPRED_HOME=/home/lequoctan/hadoop</value>
  </property>
  <property>
    <name>mapreduce.map.env</name>
    <value>HADOOP_MAPRED_HOME=/home/lequoctan/hadoop</value>
  </property>
  <property>
    <name>mapreduce.reduce.env</name>
    <value>HADOOP_MAPRED_HOME=/home/lequoctan/hadoop</value>
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

#### yarn-site.xml
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

#### hadoop-env.sh
Bổ sung:
```bash
export JAVA_HOME=/opt/jdk8
export PATH=$JAVA_HOME/bin:$PATH
export HADOOP_NAMENODE_OPTS="-Xms512m -Xmx1024m $HADOOP_NAMENODE_OPTS"
export HADOOP_DATANODE_OPTS="-Xms512m -Xmx1024m $HADOOP_DATANODE_OPTS"
export HADOOP_SECONDARYNAMENODE_OPTS="-Xms512m -Xmx1024m $HADOOP_SECONDARYNAMENODE_OPTS"
export YARN_RESOURCEMANAGER_OPTS="-Xms512m -Xmx1024m $YARN_RESOURCEMANAGER_OPTS"
export YARN_NODEMANAGER_OPTS="-Xms512m -Xmx1024m $YARN_NODEMANAGER_OPTS"
```

### 2.6. Khởi tạo HDFS
```bash
mkdir -p ~/hadoop_tmp/dfs/name
mkdir -p ~/hadoop_tmp/dfs/data
hdfs namenode -format
```

### 2.7. Khởi động Hadoop
```bash
stop-dfs.sh
stop-yarn.sh
start-dfs.sh
start-yarn.sh
```

---

## 3. Chuẩn bị & Chạy Personalized PageRank

### 3.1. Chuẩn bị mã nguồn
- Đảm bảo các file sau có trong thư mục làm việc:
  - `create_graph.py`: Tạo dữ liệu đầu vào cho PageRank.
  - `pagerank_mapper.py`: Script Map cho Hadoop Streaming.
  - `pagerank_reducer.py`: Script Reduce cho Hadoop Streaming.
  - `run_ppr.sh`: Script shell tự động hóa pipeline PPR.

- Cấp quyền thực thi:
```bash
chmod +x pagerank_mapper.py pagerank_reducer.py run_ppr.sh
```

### 3.2. Tạo dữ liệu đầu vào
```bash
python3 create_graph.py
```
File `pagerank_init.txt` sẽ được tạo.

### 3.3. Chạy thuật toán PPR
```bash
bash run_ppr.sh
```
Kết quả xếp hạng cuối sẽ được lưu ở `~/ppr_ranking.txt`.

---

## 4. Mô tả các file mã nguồn

- **create_graph.py**: Tạo file `pagerank_init.txt` từ đồ thị mẫu, khởi tạo giá trị PPR.
- **pagerank_mapper.py**: Nhận input, phát đóng góp PageRank cho các node lân cận, xử lý dangling node, phát lại adjacency list.
- **pagerank_reducer.py**: (Bạn cần bổ sung) Nhận các đóng góp, tính toán PPR mới cho mỗi node, xử lý teleport về source.
- **run_ppr.sh**: Tự động hóa pipeline: upload dữ liệu lên HDFS, lặp MapReduce, kiểm tra hội tụ, gom kết quả cuối.

---

## 5. Ghi chú
- Đảm bảo Hadoop và Java đã cài đặt, cấu hình đúng.
- Nếu gặp lỗi quyền, kiểm tra lại quyền thực thi các script.
- Có thể cần chỉnh lại đường dẫn tuyệt đối trong các file cấu hình cho phù hợp với máy của bạn. 