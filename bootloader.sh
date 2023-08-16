#!/bin/bash
#------------------ Service to synchronize with S3 -----------------

sudo mkdir -p /emr/notebooks
sudo mkdir /etc/systemd/system/sync_timer

# Create sync folders
echo '#!/bin/bash
sudo aws s3 sync s3://pao-emr-bucket/notebooks /emr/notebooks && \
sudo aws s3 sync /emr/notebooks s3://pao-emr-bucket/notebooks
' > sync_script.sh

# Make the script executable
sudo chmod +x sync_script.sh

# Create systemd service unit
echo '[Unit]
Description=Sync S3 and local directory every minute

[Service]
Type=simple
ExecStart=/etc/systemd/system/sync_timer/sync_script.sh

[Install]
WantedBy=default.target
' > sync.service

# Create systemd timer unit
echo '[Unit]
Description=Run the sync service every minute

[Timer]
OnActiveSec=30
OnUnitActiveSec=60
Unit=sync.service

[Install]
WantedBy=timers.target
' > sync.timer

# Move units to systemd directory
sudo mv sync_script.sh /etc/systemd/system/sync_timer/
sudo mv sync.service /etc/systemd/system/
sudo mv sync.timer /etc/systemd/system/

#------------- Install virtualenv and kernel ------------

python3 -m venv /emr/pyspark-pao
/emr/pyspark-pao/bin/python3 -m pip install --upgrade pip
/emr/pyspark-pao/bin/python3 -m pip install scikit-learn pandas tensorflow Pillow pyspark pyarrow keras s3fs ipykernel jupyterlab
sudo /emr/pyspark-pao/bin/python3 ipykernel install --name pyspark-pao --display-name "Pyspark"
/emr/pyspark-pao/bin/python3 jupyter lab --generate-config

# Add environment variable assignments to .bashrc
echo 'export SPARK_HOME="/usr/lib/spark"' >> ~/.bashrc
echo 'export PYTHONPATH="/emr/pyspark-pao/bin/python3":$PYTHONPATH' >> ~/.bashrc
echo 'export PYSPARK_DRIVER_PYTHON="jupyter"' >> ~/.bashrc
echo 'export PYSPARK_DRIVER_PYTHON_OPTS="notebook"' >> ~/.bashrc
echo 'export PYSPARK_PYTHON="/emr/pyspark-pao/bin/python3"' >> ~/.bashrc
echo 'source /emr/pyspark-pao/bin/activate' >> ~/.bashrc

# Send environment variables to /etc/environment
echo 'export SPARK_HOME="/usr/lib/spark"' >> /etc/environment
echo 'export PYTHONPATH="/emr/pyspark-pao/bin/python3":$PYTHONPATH' >> /etc/environment
echo 'export PYSPARK_DRIVER_PYTHON="jupyter"' >> /etc/environment
echo 'export PYSPARK_DRIVER_PYTHON_OPTS="notebook"' >> /etc/environment
echo 'export PYSPARK_PYTHON="/emr/pyspark-pao/bin/python3"' >> /etc/environment

#------------- Create Jupyter Lab service --port 8888 ---------------------
USERNAME=hadoop
NOTEBOOK_DIR=/emr/notebooks
PYTHON_BIN=/emr/pyspark-pao/bin/python3

# Create the service unit file content
SERVICE_CONTENT="[Unit]
Description=Jupyter Lab Service
After=network.target

[Service]
Type=simple
User=$USERNAME
WorkingDirectory=$NOTEBOOK_DIR
ExecStart=$PYTHON_BIN -m jupyter lab --notebook-dir=$NOTEBOOK_DIR --no-browser --autoreload --port 8888
Restart=always

[Install]
WantedBy=multi-user.target
"

# Write the content to the service unit file
SERVICE_FILE="/etc/systemd/system/jupyter-lab.service"
echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null


# Reload systemd
sudo systemctl daemon-reload


#---------------- Load and run Services ---------------------

# Start and enable jupyter service
sudo systemctl enable jupyter-lab
sudo systemctl start jupyter-lab

# Enable and start the timer
sudo systemctl enable sync.timer
sudo systemctl start sync.timer
