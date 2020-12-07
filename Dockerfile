FROM gradle:6.6-jdk11 as java_generator
WORKDIR /home/project

ARG nexus_url
ARG nexus_user
ARG nexus_password

ARG pypi_repository_url
ARG pypi_user
ARG pypi_password

COPY ./ .
RUN ./gradlew clean build publish \
    -Pnexus_url=${nexus_url} \
    -Pnexus_user=${nexus_user} \
    -Pnexus_password=${nexus_password}

FROM nexus.exactpro.com:9000/th2-python-service-generator:1.1.1 as python_service_generator
WORKDIR /home/project
COPY ./ .
RUN /home/service/bin/service -p src/main/proto/th2_grpc_sim -w PythonServiceWriter -o src/gen/main/python/th2_grpc_sim

FROM python:3.8-slim as python_generator
ARG pypi_repository_url
ARG pypi_user
ARG pypi_password

WORKDIR /home/project
COPY --from=python_service_generator /home/project .
RUN printf '{"package_name":"%s","package_version":"%s"}' "$app_name" "$app_version" > "package_info.json" && \
    pip install -r requirements.txt && \
    python setup.py generate && \
    python setup.py sdist && \
    twine upload --repository-url ${pypi_repository_url} --username ${pypi_user} --password ${pypi_password} dist/*
