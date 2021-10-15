import json
import os
import sys

def print_critical(name):
	for i in range(1, 6):
		with open(os.path.join(name, str(i)+'.json')) as f:
			try:
				metrics = json.load(f)
				print('{0:.3f} {1:.3f} {2:.3f}'.format(metrics['avg_tput'], metrics['p99_lat_commit'], metrics['p99_lat_exec']))
			except:
				print('nan nan')

if __name__ == "__main__":
	expr_name = sys.argv[1]
	print_critical(expr_name)
