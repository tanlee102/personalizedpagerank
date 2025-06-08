#!/usr/bin/env bash
set -euo pipefail

BASE_HDFS="/user/$(whoami)/pagerank_ppr"
STREAMING_JAR="$HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar"
MAPPER="pagerank_mapper.py"
REDUCER="pagerank_reducer.py"
NUM_REDUCERS=1
MAX_ITER=5
EPSILON=1e-4
total_nodes_file="total_nodes.txt"

# 0) Chắc các file mapper/reducer đã executable
chmod +x $MAPPER $REDUCER

# 1) Chuẩn bị HDFS
hdfs dfs -rm -r -f $BASE_HDFS/iter_* $BASE_HDFS/all_iters
hdfs dfs -mkdir -p $BASE_HDFS/input $BASE_HDFS/iter_0

# 2) Tạo total_nodes.txt (dù reducer giờ không cần, nhưng giữ nguyên)
total_nodes=$(awk 'END{print NR}' pagerank_init.txt)
echo $total_nodes > $total_nodes_file

# 3) Đưa pagerank_init.txt và total_nodes.txt lên HDFS
hdfs dfs -put -f pagerank_init.txt $BASE_HDFS/input/
hdfs dfs -put -f $total_nodes_file $BASE_HDFS/

# 4) Khởi tạo iter_0: copy pagerank_init.txt thành part-00000
hdfs dfs -cp -f $BASE_HDFS/input/pagerank_init.txt $BASE_HDFS/iter_0/part-00000

LAST_ITER=0
for ((i=1; i<=MAX_ITER; i++)); do
  in_dir=$BASE_HDFS/iter_$((i-1))
  out_dir=$BASE_HDFS/iter_$i
  echo "=== Iter $i ==="
  hdfs dfs -rm -r -f $out_dir

  # 5) Chạy Hadoop Streaming
  hadoop jar $STREAMING_JAR \
    -D mapreduce.job.reduces=$NUM_REDUCERS \
    -files $MAPPER,$REDUCER,$total_nodes_file \
    -mapper "python3 $MAPPER" \
    -reducer "python3 $REDUCER" \
    -input $in_dir \
    -output $out_dir

  # 6) Check convergence: sort key trước khi paste
  prev_sorted=/tmp/prev_sorted_$i
  curr_sorted=/tmp/curr_sorted_$i

  hdfs dfs -cat $BASE_HDFS/iter_$((i-1))/part-* | sort -k1,1 > $prev_sorted
  hdfs dfs -cat $out_dir/part-*         | sort -k1,1 > $curr_sorted

  max_delta=$(paste $prev_sorted $curr_sorted \
    | awk '{d = $2 - $4; if (d<0) d = -d; print d}' \
    | sort -n | tail -1)

  echo "Max delta = $max_delta"

  rm -f $prev_sorted $curr_sorted

  LAST_ITER=$i
  if awk "BEGIN{exit !($max_delta < $EPSILON)}"; then
    echo "Converged at $i"
    break
  fi
done

# 7) Gom kết quả cuối vào all_iters
hdfs dfs -rm -r -f $BASE_HDFS/all_iters
hdfs dfs -mkdir -p $BASE_HDFS/all_iters
for ((j=1; j<=LAST_ITER; j++)); do
  echo "Copy iter_$j → all_iters"
  hdfs dfs -cp -f $BASE_HDFS/iter_$j/part-* $BASE_HDFS/all_iters/
done

echo "Done. Results in $BASE_HDFS/all_iters"

# 8) Xuất kết quả cuối về local & ranking
SOURCE="P1"
hdfs dfs -cat "${BASE_HDFS}/all_iters/"* > /tmp/ppr_final.tsv

awk -v src="$SOURCE" -F $'\t' '$1!=src { print $1, $2 }' /tmp/ppr_final.tsv \
  | sort -k2,2nr \
  | awk '{ printf("%d\t%s\t%f\n", NR, $1, $2) }' \
  > ~/ppr_ranking.txt

echo "✅ PPR ranking (excluding $SOURCE) written to ~/ppr_ranking.txt"
cat ~/ppr_ranking.txt