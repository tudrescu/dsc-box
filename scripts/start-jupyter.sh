#!/bin/bash
export CONDA_DIR=/opt/conda
export PATH=$CONDA_DIR/bin:$PATH
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --notebook-dir='/vagrant/' --NotebookApp.token=
