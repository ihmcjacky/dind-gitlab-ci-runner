# Gitlab Runner Dockerfile for AWS Lightsail Deployment

This Dockerfile is designed to create a custom GitLab runner image for deploying to AWS Lightsail. The image includes necessary dependencies and configurations to run GitLab CI/CD pipelines on AWS Lightsail instances. You can pick any devices as the runner, with docker installed.

The Dockerfile performs the following tasks:
1. Installs dependencies such as openssh-client, python3, py3-pip, and curl.
2. Downloads and installs Docker Compose v2 (standalone binary) for modern Docker CLI compatibility.
3. Installs the AWS CLI using a virtual environment to avoid PEP 668 restrictions.
4. Configures SSH access by adding the public key to the authorized_keys file.
5. Sets the entrypoint to start the SSH daemon.

# Usage and maintenance of the gitlab runner
The following are useful commands for creating and maintaining the gitlab runner.

## Create the docker volume for the runner (once only)

The volume is used to persist the gitlab runner configuration.
```bash
docker volume create gitlab-runner
```
## Build the custom runner image
The custom runner image is necessary to install dependencies such as aws cli, docker compose etc. It is designed to fit for the CI / CD pipeline of Supreme AV project and all other Maxwell projects with similar setup. You may need to customize it for your own project.

```bash
docker build -t registry.gitlab.com/maxwellhk/supremeav/ci-build-image -f ./aws.runner.dockerfile .
```
The image is tagged with the registry.gitlab.com/maxwellhk/supremeav/ci-build-image. Change the tag to your own registry if necessary. This example shows the CI build image for Supreme AV project. It is being stored in corresponding project repository. 

On the other hand, you can also clone it from registry.gitlab.com/maxwellhk/supremeav/ci-build-image:latest and run it directly.

## Create the runner
```bash
docker run -d --name gitlab-runner --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v gitlab-runner:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

If you run in Windows PowerShell, you may need to use the following command to create the runner:
```powershell
docker run -d --name gitlab-runner --restart always `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v gitlab-runner:/etc/gitlab-runner `
  gitlab/gitlab-runner:latest
```

## Register the runner
```bash
docker exec -it gitlab-runner gitlab-runner register
```

Follow the on screen instruction to register the runner with the gitlab server.

## Docker in docker
The gitlab runner is designed to run docker in docker. First layer of docker is the gitlab runner itself. The second layer of docker is the docker daemon that is used to run the docker commands. 

The following options in config.toml is required to enable docker in docker.

```toml
[[runners]]
  name = "gitlab-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "docker"
  [runners.docker]
    image = "docker:latest"
    privileged = true
    volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
```

- `privileged = true` is required to enable docker in docker.
- `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]` is required to enable docker in docker.

## Run the custom runner
```bash
docker run -d --name gitlab-runner --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v gitlab-runner:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

## Adding CI / CD variables
Some variables needed to be pre-configured in the gitlab CI / CD variables. Please refer to the following table for the variables needed.

Variables | Value | Type | Description | Points to note
--- | --- | --- | --- | ---
SSH_PRIVATE_KEY_FILE | The private key of the runner | File | Content of the private key of the host machine | Value cannot be masked since it is a "File" type
SSH_KNOWN_HOSTS | The known hosts of the runner | File | Content of the known hosts of the host machine | Value cannot be masked since it is a "File" type
AWS_ACCESS_KEY_ID | The access key id of the AWS account | Variable | The access key id of the AWS account | Value can be masked
AWS_SECRET_ACCESS_KEY | The secret access key of the AWS account | Variable | The secret access key of the AWS account | Value can be masked
AWS_ACC_ID | The account id of the AWS account | Variable | The account id of the AWS account | Value can be masked

Note: During the runner setup process, I discovered that the "Variable" type with masked is not allowed for the private key and known hosts since whitespaces characters are not allowed. Therefore, I have to use the "File" type instead.

# Example of gitlab-ci.yml
The below shows a sample of the gitlab-ci.yml file for reference using the runner created from this dockerfile. Please note that the variables used are just examples and you should replace them with your own variables.

```
# Release yml by Jacky Lam

# Points to Note
# ================================================================================
# * Run in docker executor (DinD)
# * Update the SUPREME_VER variable, tag and push the branch, pipeline will run automatically
# * Make sure all AWS related variables are added and configured to the CI / CD variables in gitlab project settings

##################################################################################

Runner process:
# 1. Login to AWS
# 2. Update env version to desired version
# 3. Build and push the image

variables:
    SUPREME_VER: 'v2.11.19'
    REGION: 'us-east-2'
    SAIL_IP: 'SOME_IP'
    SAIL_HOME: 'REMOTE_SERVER_HOME_DIRECTORY'

stages:
    - build

build:
    image: registry.gitlab.com/maxwellhk/supremeav/ci-build-image:latest
    # Define the Docker-in-Docker service
    services:
        - name: docker:24.0.7-dind
          alias: docker
    variables:
        # Instructs the docker CLI to connect to the dind service daemon
        DOCKER_HOST: tcp://docker:2375
        # Disables TLS, which is not needed for this internal connection
        DOCKER_TLS_CERTDIR: ""
        # Recommended for dind to improve performance
        DOCKER_DRIVER: overlay2
    before_script:
        # Make the ssh-agent available to all scripts
        - eval $(ssh-agent -s)
        # Add the private key to the ssh-agent (borrowed from host machine, the runner)
        - chmod 600 "$SSH_PRIVATE_KEY_FILE"
        - ssh-add "$SSH_PRIVATE_KEY_FILE"
        # Create the .ssh directory and add the known_hosts entry
        - mkdir -p ~/.ssh
        - chmod 700 ~/.ssh
        - echo "$SSH_KNOWN_HOSTS" >> ~/.ssh/known_hosts
        # Set the permission of the known_hosts file
        - chmod 644 ~/.ssh/known_hosts
        # Wait for the docker daemon to be ready
        - while ! docker info; do sleep 1; done
        # Login to AWS
        - export AWS_DEFAULT_REGION=$REGION
        - $(aws ecr get-login --no-include-email)
        # Update the env file with the desired version (for showing in about page)
        - sed -i "/SUPREME_VER/c\SUPREME_VER=$SUPREME_VER" ./src/.env
        - cd ./src
    stage: build
    script: 
        - docker compose -f ./docker-compose-aws-prod.yml build
        - docker compose -f ./docker-compose-aws-prod.yml push
        - scp .env ec2-user@$SAIL_IP:$SAIL_HOME/.env
        - ssh ec2-user@$SAIL_IP "docker-compose -f ${SAIL_HOME}/docker-compose-aws-prod.yml stop"
        - ssh ec2-user@$SAIL_IP "$(aws ecr get-login --no-include-email)"
        - ssh ec2-user@$SAIL_IP "docker pull ${AWS_ACC_ID}.dkr.ecr.us-east-2.amazonaws.com/supremeav-front:${SUPREME_VER}"
        - ssh ec2-user@$SAIL_IP "docker pull ${AWS_ACC_ID}.dkr.ecr.us-east-2.amazonaws.com/supremeav-back:${SUPREME_VER}"
        - ssh ec2-user@$SAIL_IP "docker-compose -f ${SAIL_HOME}/docker-compose-aws-prod.yml --project-directory=${SAIL_HOME} up -d"
    only:
        - tags
        - /^v[0-9]\..*$/
```