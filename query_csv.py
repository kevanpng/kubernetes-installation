import csv
import requests
import sys


if len(sys.argv) != 7:
    raise ValueError(f'wrong number of args. Current Args: {sys.argv}')

host = sys.argv[1]
query = sys.argv[2]
start = sys.argv[3]
end = sys.argv[4]
output_file_name = sys.argv[5]
metric_name = sys.argv[6]


def main():
    response = requests.get(
        f'http://{host}/api/v1/query_range',
        params={
            'query': query,
            'start': start,
            'end': end,
            'step': 1,
        },
    )
    results = response.json()['data']['result'][0]['values']
    with open(f'./{output_file_name}', 'w') as f:
        writer = csv.writer(f)
        writer.writerow(['timestamp', metric_name])
        for result in results:
            writer.writerow(result)


if __name__ == '__main__':
    main()
