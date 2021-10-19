import os
import sys
import matplotlib.pyplot as plt

def parse_log():
	n_call = []
	time = []
	with open('server.log', 'r') as f:
		call = 0
		for l in f:
			if 'call' in l:
				call = call + 1
			elif 'us' in l:
				l = l.split(' ')
				t = int(l[2])
				if t < 1000000:
					n_call.append(call)
					time.append(t)
				call = 0
	
	plt.plot(n_call, time)
	plt.show()
	

if __name__ == '__main__':
	parse_log()
