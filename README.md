# Gitlab Runner Dockerfile for AWS Lightsail Deployment

This Dockerfile is designed to create a custom GitLab runner image for deploying to AWS Lightsail. The image includes necessary dependencies and configurations to run GitLab CI/CD pipelines on AWS Lightsail instances.

The Dockerfile performs the following tasks:
1. Installs dependencies such as openssh-client, python3, py3-pip, and curl.
2. Downloads and installs Docker Compose v2 (standalone binary) for modern Docker CLI compatibility.
3. Installs the AWS CLI using a virtual environment to avoid PEP 668 restrictions.
4. Configures SSH access by adding the public key to the authorized_keys file.
5. Sets the entrypoint to start the SSH daemon.

It also includes a script to convert private key of the host machine to base64 encoded format, it is then added as a CI/CD variable for the pipeline to use. Note that the private key is "borrowed" from the host machine and is not generated within the container because the runner is temporary and short-lived. The private key is fed into the container by cat command during the execution of the pipeline. For security reason, the private key is not stored in the container and is not part of the image and will be removed after the pipeline is completed.

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
