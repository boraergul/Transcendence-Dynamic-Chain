#!/usr/bin/python
import os
import json
import subprocess

if __name__ == "__main__":
    command=r""" ls -la /usr/share/ | grep "\.transcendence" | cut -d "." -f 2 | cut -d "_" -f 2 """
    nodes = (subprocess.check_output(command, shell=True)).rsplit()

    data = [{"{#NODENAME}": node} for node in nodes]
    print(json.dumps({"data": data}, indent=4))
