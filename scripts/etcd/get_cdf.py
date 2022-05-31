def get_cdf_etcd(filename: str):
	with open(filename, 'r') as f:
		seen = False
		cdf = []
		for line in f:
			if 'Requests/sec' in line:
				avg_tput = float(line.rstrip('\n').split(':\t')[1])
			if not seen and 'Latency distribution' in line:
				seen = True
			elif seen:
				try:
					lat = float(line.rstrip('\n').split(': ')[1])
					cdf.append(lat * 1000)
				except:
					pass

		return avg_tput, cdf

if __name__ == '__main__':
	print(get_cdf_etcd('experiments/etcd_8c_3r_trial1.txt'))