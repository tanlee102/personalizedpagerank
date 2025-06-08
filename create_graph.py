# Đồ thị dưới dạng danh sách kề (adjacency list)
graph = {
    "P1": ["P2", "P3"],
    "P2": [],
    "P3": ["P1", "P2", "P5"],
    "P4": ["P5", "P6"],
    "P5": ["P4", "P6"],
    "P6": ["P4"]
}

# Nút nguồn trong Personalized PageRank
SOURCE = "P1"

with open("pagerank_init.txt", "w") as f:
    for node in sorted(graph.keys()):
        pr_init = 1.0 if node == SOURCE else 0.0
        neighbors = ",".join(graph[node])
        f.write(f"{node}\t{pr_init}\t{neighbors}\n")