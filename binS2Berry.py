# helper script to export ULP code from an ESP-IDF project to Tasmotas Berry
#
# usage: launch "python3 binS2Berry.py" in root folder of the project

from os import walk, path
from os.path import exists, join, abspath
from base64 import b64encode
import sys
import math

# Search for ulp_main.bin.S and ulp_main.sym in the build directory and its subdirectories.
def search_ulp_files():
    print("Searching ESP-IDF build folder ...")

    bin_file = ""
    sym_file = ""

    if not exists('build'):
        print("Error: 'build' directory not found. Please run this script in a valid ESP-IDF project folder with a completed build.")
        sys.exit(1)

    for root, dirs, files in walk('build'):
        for file in files:
            if file == "ulp_main.bin.S":
                bin_file = abspath(join(root, file))
            if file == "ulp_main.sym":
                sym_file = abspath(join(root, file))

    if not bin_file:
        print("Warning: 'ulp_main.bin.S' not found in build directory.")
    if not sym_file:
        print("Warning: 'ulp_main.sym' not found in build directory.")

    return bin_file, sym_file

def parse_bin_file(bin_file):
    print("Parsing bin file:", bin_file)
    code = ""
    size_in_file = 0
    with open(bin_file, 'r', encoding='UTF-8') as file:
        while (line := file.readline()):
            if line.startswith(".byte") or line.startswith("0x"):
                hexstring = line.replace(".byte ","").replace(", ","").replace("0x","")
    #            print(hexstring)
                code += hexstring.rstrip().replace("\n","")
            if line.startswith(".long"):
                tokens = line.split(" ")
                size_in_file = int(tokens[1])

    code_size = int(len(code)/2)
    if code_size != size_in_file:
        print("Parsing error!")
        print("Mismatch of size in file:",size_in_file," vs parsed size:", code_size)
    if code_size%4 != 0:
        print("Parsing error!")
        print("No long word alignement.")

    code_b64 = b64encode(bytes.fromhex(code)).decode()
    return code, code_b64, code_size

def parse_sym_file(sym_file):
    print("Parsing sym file:", sym_file)
    global_vars = []
    with open(sym_file, 'r') as f:
        for line in f:
            if ' GLOBAL ' in line:  # Look for global symbols
                global_vars.append(line)
    return global_vars

def main(args):
    bin_file, sym_file = search_ulp_files()
    code, code_b64, code_size = parse_bin_file(bin_file)
    global_vars = parse_sym_file(sym_file)

    print("")
    print(f"# Code length: {code_size} bytes, {math.ceil(code_size / 4)} words; Paste the following snippet into Tasmotas Berry console:")
    print("import ULP")
    print("ULP.wake_period(0, 1000 * 1000)")
    print("# Global vars")
    for line in global_vars:
        parts = line.split()
        if len(parts) >= 8 and parts[3] == "OBJECT" and parts[4] == "GLOBAL" and parts[6] == "2":
            var = parts[-1]
            rtc_addr =  int(int(parts[1], 16) / 4)
            print(f"ULP.set_mem({rtc_addr},0) # {var}")
    print("var c = bytes().fromb64(\"" + code_b64 + "\")")
    print("ULP.load(c)")
    print("ULP.run()")

if __name__ == '__main__':
  sys.exit(main(sys.argv))
