#!/usr/bin/python3
import subprocess
import sys

def run(args):
    with subprocess.Popen(args, bufsize=1, stderr=subprocess.PIPE, universal_newlines=True) as proc:
        for line in proc.stderr:
            print("stderr: ", line, end="")
        proc.stderr.close()
        print("exit code=", proc.wait())

run(sys.argv[1:])

