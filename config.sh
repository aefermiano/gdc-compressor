#!/bin/bash

HASH_COMMAND="sha1sum _FILE_NAME_ -b | awk '{print \$1}'"
PROGRESS_COMMAND="pv --progress --timer --eta --rate --bytes --size _FILE_SIZE_"

XZ_DICTIONARY_SIZE="1610612736" # ~infinity, memory limit will automatically adjust this
XZ_MEMORY_LIMIT="7G"            # You can increase this if you have more RAM
XZ_THREADS="1"                  # Using single thread let you use bigger dictionary with same RAM
