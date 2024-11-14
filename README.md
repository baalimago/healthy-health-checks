# Healthy healthchecks

This repo is a companion to [my blog post exploring healthchecks](https://lorentz.app/blog-item.html?id=healthy-healthchecks).
It focuses primarily on ECS, but also enables local healtcheck exploration, using Terraform for deployment.

## Prerequisites

There are certain tools needed to deploy this for yourself.

- [Go](https://go.dev/doc/install) is used to build the binary, if you wish to start it locally before containerizing it
- [Docker](https://docs.docker.com/engine/install/) is used to containerize the go binary
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) is used to deploy both local and remote resources
- [AWS](https://aws.amazon.com/getting-started/guides/setup-environment/) is used for the cloud resources. Ensure you also install the CLI

## Starting it locally

Depending on what you wish to check out, there are different ways to start this project.
Let's begin at the core:

### Starting the go process

`HEALTHY_AFTER_DURATION=5s go run main.go`
Try removing HEALTHY_AFTER_DURATION and note how the application doesn't start.
Checkout [main.go](./main.go) to find out why.

To verify that it works, let's try out the healthcheck by calling it using [curl](https://curl.se/) (most likely already installed in your shell).
`curl -v localhost:8080/health`

Expect to see the line `< HTTP/1.1 200 OK`, this is the status code response.
Also expect to see `Now I'm healthy.`, which means that our mocked health process is healthy.

Try changing [main.go](./main.go) to find out how it works!

### Dockerization station

`docker build -f Dockerfile_no-healthcheck -t="healthy-healthchecks:no-healthcheck" .`

Note how we're building [a version without healthcheck](./Dockerfile_no-healthcheck).
Can you build [another one](./Dockerfile_with-healthcheck) which has healthchecks?

Let's start it by running:
`docker run -e HEALTHY_AFTER_DURATION=10s -p 8080:8080 healthy-healthchecks:with-healthcheck`

Now, depending on if you turned off your earlier go process or not, which is occupying the port `8080`, this might not work.
If Docker gets upset and says `Bind for 0.0.0.0:8080 failed: port is already allocated.`, then either turn your go process off, or change the port from `8080` -> something else by changing the port `-p 8080:8080` flag.

### Terraform it

All of these steps can be automated by using Terraform.
Modify [the auto commands file](./variables.auto.tfvars) and set `start_local=true` and ensure `start_remote=false`, to not start the pesky remote resources just yet.
Then, run:

1. `terraform apply`
1. Inspect the resource you're about to provision and ensure you're not getting hacked
1. Provision them by typing `yes`

Now you will have spawned 3 docker containers, run `docker ps` to find out which.
The building is done by the [docker-image](./module/docker-image) module, and the local start is done by the [local module](./module/local/)

Try out the different dockre containers by using `curl` once more.
Run `docker ps` to find which ports to target.

If you wish to restart the containers, run:

1. `terraform destroy`
1. Type 'yes' to de-provision the resources
1. `terraform apply`
1. Type 'yes' to apply
