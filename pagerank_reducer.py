#!/usr/bin/env python3
import sys

D = 0.85
SOURCE = "P1"

dangling_sum = 0.0
partial = {}

# 1) Đọc toàn bộ đầu vào (map output) từ stdin
for line in sys.stdin:
    line = line.rstrip()
    if not line:
        continue
    key, val = line.split('\t', 1)
    if key == "__dangling__":
        # Gom toàn bộ mass của các dangling node
        try:
            dangling_sum += float(val)
        except:
            pass
    else:
        # Lưu lại tất cả giá trị (đóng góp hoặc "ADJ|...")
        partial.setdefault(key, []).append(val)

# 2) Xử lý từng node, tính pr_new
for node, values in partial.items():
    sum_contrib = 0.0
    adj_list = ""
    for v in values:
        if v.startswith("ADJ|"):
            adj_list = v.split("ADJ|", 1)[1]
        else:
            try:
                sum_contrib += float(v)
            except:
                pass

    # Nếu là SOURCE, cộng toàn bộ dangling_sum; khác thì chỉ nhận sum_contrib
    if node == SOURCE:
        pr_new = (1.0 - D) + D * (sum_contrib + dangling_sum)
    else:
        pr_new = D * sum_contrib

    print(f"{node}\t{pr_new}\t{adj_list}")
