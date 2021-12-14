import csv
import requests
import sys


if len(sys.argv) != 6:
    raise ValueError(f'wrong number of args. Current Args: {sys.argv}')


def main():
    response = requests.get(
        f'http://{sys.argv[1]}/api/v1/query_range',
        params={
            'query': sys.argv[2],
            'start': sys.argv[3],
            'end': sys.argv[4],
            'step': 1,
        }
    )
    results = response.json()['data']['result'][0]['values']
    with open(f'./{sys.argv[5]}', 'w') as f:
        writer = csv.writer(f)
        writer.writerow(['timestamp', 'value'])
        for result in results:
            writer.writerow(result)


if __name__ == '__main__':
    main()
