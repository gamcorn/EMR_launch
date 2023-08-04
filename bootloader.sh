#!/bin/bash

#sudo mkdir -p /var/lib/jupyter/home/jovyan/notebooks
#
#sudo aws s3 sync s3://pao-emr-bucket/notebooks /var/lib/jupyter/home/jovyan/notebooks

python3 -m pip install -U setuptools
python3 -m pip install -U pip
python3 -m pip install wheel boto3 scikit-learn pandas tensorflow pillow pyarrow boto3 s3fs fsspec
