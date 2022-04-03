FROM jupyter/pyspark-notebook:spark-3.1.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY entrypoint.sh /entrypoint.sh

USER root
RUN chmod 777 /entrypoint.sh


# Install Azurite (support wasb-protocol storage for Delta tables in integration tests)
RUN apt-get update; \
    apt-get install -y npm && npm install -g n && n lts && hash -r && npm install -g azurite

RUN conda install --quiet --yes --satisfied-skip-solve \
    'pyarrow=2.0.*' 'rope=0.18.*' 'pytest=6.1.*' 'autopep8=1.5.*' 'configargparse=1.2.3'  \
    'coverage=5.3.*' 'azure-storage-blob=12.8.*' 'pytest-mock=3.5.*' \
    && \
    conda install --quiet --yes --satisfied-skip-solve -c anaconda 'protobuf=3.14.*' && \
    pip --no-cache-dir install pyspelling azure-eventhub coverage-threshold ptvsd azure-servicebus protodf delta-spark pytest-asyncio flake8 black && \
    conda clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

ENTRYPOINT ["/entrypoint.sh"]