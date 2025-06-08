# Personalized PageRank (PPR) trên Hadoop MapReduce

## Giới thiệu

**Personalized PageRank (PPR)** là một biến thể của thuật toán PageRank, cho phép cá nhân hóa thứ tự các nút trong đồ thị dựa trên một nút nguồn (source) do người dùng chỉ định. PPR thường được ứng dụng trong tìm kiếm cá nhân hóa, gợi ý nội dung, phân tích mạng xã hội, v.v.

Thuật toán được triển khai trên nền tảng Hadoop MapReduce, tận dụng khả năng xử lý phân tán cho các đồ thị lớn.

---

## Lý thuyết & Ý tưởng cài đặt

- **PPR** điều chỉnh PageRank chuẩn bằng cách luôn teleport về node nguồn (source) thay vì ngẫu nhiên.
- **Công thức cập nhật:**
  - Nếu node là source:  
    \( PR_{new}(i) = (1-d) + d \times (\text{sumContrib} + \text{danglingSum}) \)
  - Nếu node khác source:  
    \( PR_{new}(i) = d \times \text{sumContrib} \)
  - \( d \): hệ số damping (thường 0.85)
  - sumContrib: tổng đóng góp từ các node trỏ tới \( i \)
  - danglingSum: tổng PageRank từ các node không có outbound link

- **Luồng MapReduce:**
  - **Input:** Đồ thị dạng danh sách kề, mỗi dòng: `node_id \t PR_value \t neighbor1,neighbor2,...`
  - **Map:** Phân phối giá trị PageRank cho các node lân cận, xử lý dangling node, phát lại adjacency list.
  - **Reduce:** Tổng hợp đóng góp, cộng thêm phần teleport về source, cập nhật giá trị PPR cho mỗi node.
  - **Lặp ngoài:** Script shell điều khiển số vòng lặp, kiểm tra hội tụ (max delta), gom kết quả cuối.

---

## Kiến trúc & Luồng Dữ Liệu

1. **Tạo dữ liệu đầu vào:**
   - Đồ thị mẫu được định nghĩa trong `create_graph.py`.
   - File `pagerank_init.txt` chứa: node, giá trị PPR khởi tạo, danh sách kề.
2. **Chạy MapReduce nhiều vòng:**
   - Mỗi vòng: Mapper phân phối PR, Reducer tổng hợp và cập nhật.
   - Kiểm tra hội tụ dựa trên max delta giữa hai vòng liên tiếp.
3. **Kết quả cuối:**
   - Gom lại, xếp hạng và xuất ra file.

---

## Các File Chính

| Tên file              | Mô tả                                                        |
|-----------------------|--------------------------------------------------------------|
| `create_graph.py`     | Tạo file khởi tạo PageRank (`pagerank_init.txt`) từ đồ thị mẫu|
| `pagerank_mapper.py`  | Script Python cho bước Map trong Hadoop Streaming            |
| `pagerank_reducer.py` | Script Python cho bước Reduce (bạn cần bổ sung nếu chưa có)  |
| `run_ppr.sh`          | Script shell tự động hóa pipeline PPR trên Hadoop            |

---

## Hướng Dẫn Cài Đặt Hadoop (Pseudodistributed)

### 1. Cài đặt JDK 8
- Tải và cài đặt JDK 8 phù hợp với hệ điều hành của bạn.
- Đảm bảo JAVA_HOME trỏ đúng thư mục cài đặt JDK 8 (ví dụ: `/opt/jdk8`).

### 2. Tải và giải nén Hadoop
```bash
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
```

### 3. Thiết lập biến môi trường
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

### 4. Thiết lập SSH không mật khẩu
```bash
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ssh localhost   # Đảm bảo không hỏi mật khẩu
```

### 5. Cấu hình Hadoop (Pseudodistributed)
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

### 6. Khởi tạo HDFS
```bash
mkdir -p ~/hadoop_tmp/dfs/name
mkdir -p ~/hadoop_tmp/dfs/data
hdfs namenode -format
```

### 7. Khởi động Hadoop
```bash
stop-dfs.sh
stop-yarn.sh
start-dfs.sh
start-yarn.sh
```

---

## Hướng Dẫn Chạy Personalized PageRank

1. **Tạo dữ liệu đầu vào:**
   ```bash
   python3 create_graph.py
   ```
   File `pagerank_init.txt` sẽ được tạo, chứa thông tin đồ thị và giá trị PPR khởi tạo.

2. **Cấp quyền thực thi cho các script:**
   ```bash
   chmod +x pagerank_mapper.py pagerank_reducer.py run_ppr.sh
   ```

3. **Chạy pipeline PPR trên Hadoop:**
   ```bash
   bash run_ppr.sh
   ```
   Script sẽ:
   - Đưa dữ liệu lên HDFS
   - Lặp MapReduce nhiều vòng cho đến khi hội tụ
   - Xuất kết quả xếp hạng cuối cùng ra file `~/ppr_ranking.txt`

4. **Xem kết quả:**
   ```bash
   cat ~/ppr_ranking.txt
   ```

---

## Giải Thích Mã Nguồn

### create_graph.py
- Định nghĩa đồ thị mẫu dưới dạng dictionary.
- Ghi ra file `pagerank_init.txt` với PPR khởi tạo: source = 1.0, các node khác = 0.0.

### pagerank_mapper.py
- Nhận từng dòng input, tách thành node, giá trị PR, danh sách neighbors.
- Phát đóng góp PR cho từng neighbor.
- Nếu là dangling node (không có neighbor), phát giá trị PR cho key đặc biệt `__dangling__`.
- Phát lại adjacency list để Reduce có thể tái tạo cấu trúc đồ thị.

### pagerank_reducer.py
- Nhận các đóng góp từ Mapper, tổng hợp sumContrib và danglingSum.
- Áp dụng công thức PPR để tính giá trị mới cho mỗi node.
- Phát lại adjacency list cho vòng lặp tiếp theo.

### run_ppr.sh
- Tự động hóa toàn bộ pipeline:
  - Đưa dữ liệu lên HDFS, khởi tạo các thư mục/vòng lặp.
  - Chạy Hadoop Streaming với mapper/reducer.
  - Kiểm tra hội tụ dựa trên max delta giữa hai vòng liên tiếp.
  - Gom kết quả cuối, xếp hạng và xuất ra file.

---

## Lưu Ý
- Bạn cần cài đặt Hadoop và cấu hình biến môi trường `HADOOP_HOME`.
- File `pagerank_reducer.py` cần được bổ sung nếu chưa có (theo đúng logic Reduce đã mô tả).
- Đảm bảo các script Python có quyền thực thi (`chmod +x`).
- Có thể cần chỉnh lại đường dẫn tuyệt đối trong các file cấu hình cho phù hợp với máy của bạn.

---

## Tài Liệu Tham Khảo
- Brin, S., & Page, L. (1998). The anatomy of a large-scale hypertextual Web search engine.
- Özsu, M. T., & Valduriez, P. (2020). Principles of Distributed Database Systems.
- Malewicz, G. et al. (2010). Pregel: a system for large-scale graph processing.
- Bu, Y., Howe, B., Balazinska, M., & Ernst, M. D. (2010). HaLoop: efficient iterative data processing on large clusters.
- Kyrola, A., Blelloch, G., & Guestrin, C. (2012). GraphChi: large-scale graph computation on just a PC.
- Carbone, P. et al. (2015). Apache Flink™: Stream and batch processing in a single engine. 