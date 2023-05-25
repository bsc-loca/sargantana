#!/usr/bin/env python3

import os
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from glob import glob

SIMULATOR = sys.argv[1]
ISA_DIR = sys.argv[2]
TEST_TIMEOUT = 100000
IMPLEMENTED_EXTENSIONS = ['i', 'm', 'f', 'd', 'a']

TESTS_TO_SKIP = {
    "rv64ui-p-ma_data": "Core doesn't support misaligned load/stores",
    "rv64ui-v-ma_data": "Core doesn't support misaligned load/stores",
}

def format_padded(text):
    pad = '.' * 60
    padlength = 35
    return text + pad[:padlength - len(text)]

class ThreadedLogger:
    console_lock = threading.Lock()
    isConsole = sys.stdout.isatty()
    latest_line = 0

    def __init__(self):
        self.line = None
        self.previousMessage = ""

    def log(self, message):
        message = self.previousMessage + message

        if ThreadedLogger.isConsole:
            with ThreadedLogger.console_lock:
                if self.line is None:
                    self.line = ThreadedLogger.latest_line
                    ThreadedLogger.latest_line += 1
                    sys.stdout.write("%s\n" % message)
                else:
                    lines_to_move = ThreadedLogger.latest_line - self.line

                    max_lines = os.get_terminal_size().lines

                    if lines_to_move <= max_lines:
                        if lines_to_move > 0:
                            move_down = "\033[{}A".format(lines_to_move)
                            sys.stdout.write(move_down)

                        sys.stdout.write("%s\n" % message)

                        if lines_to_move > 0:
                            move_up = "\033[{}B".format(lines_to_move)
                            sys.stdout.write(move_up)
                    else:
                        self.line = ThreadedLogger.latest_line
                        ThreadedLogger.latest_line += 1
                        sys.stdout.write("%s\n" % message)

                sys.stdout.flush()

        self.previousMessage = message

    def end(self):
        if not ThreadedLogger.isConsole:
            sys.stdout.write("%s\n" % self.previousMessage)

def green(string): return f'\033[32m{string}\033[0m'

def red(string): return f'\033[31m{string}\033[0m'

def yellow(string): return f'\033[33m{string}\033[0m'

results_lock = threading.Lock()
failed_tests = []
passed_tests = 0

def run_test(test_path):
    global failed_tests, passed_tests

    test_name = os.path.basename(test_path)

    logger = ThreadedLogger()
    logger.log(format_padded("Testing " + test_name))

    if test_name not in TESTS_TO_SKIP:
        command = [SIMULATOR, "+max-cycles=" + str(TEST_TIMEOUT), "+load=" + test_path]
        try:
            result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if result.returncode == 0:
                logger.log(green("OK"))
                with results_lock:
                    passed_tests += 1
            else:
                if result.returncode == 255:
                    logger.log(red('SIM. TIMED OUT'))
                else:
                    logger.log(f'{red("FAILED")} (Test case {result.returncode})')
                with results_lock:
                    failed_tests.append(test_name)
        except subprocess.TimeoutExpired:
            logger.log(red("PROC. TIMED OUT"))
            with results_lock:
                failed_tests.append(test_name)
    else:
        logger.log(f'{yellow("SKIP")} (Reason: {TESTS_TO_SKIP[test_name]})')

    logger.end()

futures = []

with ThreadPoolExecutor(max_workers=4) as executor:
    for mode in ['u', 'm']:
        for mem in ['p', 'v']:
            for ext in IMPLEMENTED_EXTENSIONS:
                paths = glob(f'{ISA_DIR}/rv64{mode}{ext}-{mem}-*')
                for path in paths:
                    if not path.endswith('dump'):
                        futures.append(executor.submit(run_test, path))

print("\n*** SUMMARY ***")
print("Tests passed:  {}".format(passed_tests))
print("Tests skipped: {}".format(len(TESTS_TO_SKIP)))
print("Tests failed:  {}".format(len(failed_tests)))

if (len(TESTS_TO_SKIP) > 0):
    print(f'\n*** LIST OF {yellow("SKIPPED")} TESTS ***')
    for name in TESTS_TO_SKIP:
        print(f'{name}: {TESTS_TO_SKIP[name]}')

if len(failed_tests) > 0:
    print(f'\n*** LIST OF {red("FAILED")} TESTS ***')
    print(", ".join(failed_tests))

exit(len(failed_tests))