import csv
from collections import defaultdict
import requests
import sys
from time import time

host = sys.argv[1]
ingress_nginx_controller_pod_name = sys.argv[2]
end = int(time())
# start time is 10s in the past
start = end - 10
output_csv_file_name = sys.argv[3]

# Average memory usage per second
mem_query = (
    'rate(nginx_ingress_controller_nginx_process_resident_memory_bytes[1m])'
)
# Average CPU usage (in %) per second
cpu_query = f'sum(rate(container_cpu_usage_seconds_total{{pod=\"{ingress_nginx_controller_pod_name}\"}}[1m])) by (pod_name) * 100'
# Average requests per second
reqs_query = (
    'rate(nginx_ingress_controller_requests{service="foo-service"}[10s])'
)

queries = [mem_query, cpu_query, reqs_query]


def query(query_str):
    response = requests.get(
        f'http://{host}/api/v1/query_range',
        params={
            'query': query_str,
            'start': start,
            'end': end,
            'step': 1,
        },
    )
    results = response.json()['data']['result'][0]['values']
    return results


def main():
    combined_results = defaultdict(list)
    for query_str in queries:
        results = query(query_str)
        for result in results:
            timestamp = result[0]
            # remove any decimal places in the string and use the resulting
            # integer
            value = int(result[1].split('.')[0])
            combined_results[timestamp].append(value)
    with open(f'./{output_csv_file_name}', 'w') as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                'Timestamp (EPOCH)',
                'MEM (bytes)',
                'CPU (% Usage)',
                'Requests Per Second',
            ]
        )
        for k, v in combined_results.items():
            row = [k, *v]
            writer.writerow(row)


if __name__ == '__main__':
    main()
