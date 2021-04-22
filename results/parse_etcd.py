import sys

def parseetcd(path):
	ff = open(path, 'r', encoding='utf-8').read().split('\n')
	res = {}
	for lines in ff:
		if ('Requests/sec' in lines):
			res['ops'] = float(lines.split(':\t')[1])
		if ('Average' in lines):
			res['avg'] = float(lines.split(':\t')[1].split(' ')[0])
		if ('99% in' in lines):
			res['99'] = float(lines.split(' ')[4])
		if ('99.9% in' in lines):
			res['999'] = float(lines.split(' ')[4])
	
	print('ops: '+str(res['ops']))
	print('avg lat: '+str(res['avg']))
	print('99%: '+str(res['99']))
	print('99.9%: '+str(res['999']))
	return res

if __name__ == '__main__':
	path = sys.argv[1]
	parseetcd(path)
