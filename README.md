# Healthy healthchecks

This repo is a companion to [my blog post exploring healthchecks](https://lorentz.app/blog-item.html?id=healthy-health-checks).
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

All of these steps have already been automated using Terraform.
Modify [the auto commands file](./variables.auto.tfvars) and set `start_local=true` and ensure `start_remote=false`, to not start the pesky remote resources just yet.
Then, run:

1. `terraform apply`
1. Inspect the resource you're about to provision and ensure you're not getting hacked
1. Provision them by typing `yes`

Now you will have spawned 3 docker containers, run `docker ps` to find out which.
The building is done by the [docker-image](./module/docker-image) module, and the local start is done by the [local module](./module/local/)

Try out the different docker containers by using `curl` once more.
Run `docker ps` to find which ports to target.

If you wish to restart the containers, run:

1. `terraform destroy`
1. Type 'yes' to de-provision the resources
1. `terraform apply`
1. Type 'yes' to apply

## Remote deployment

To deploy remotely, ensure that you have AWS setup.
Provisioning cloud infrastructure _comes at a cost_, so remember to always tear down your resources when you're done (unless you wish to keep it running).

This remote project will [lookup your local IP address](./module/aws-ecs-lb/main.tf) and [create a firewall](./module/aws-ecs-lb/ecs.tf) which blocks all access except for the IP that you're currently running.
Keep this in mind whenever if you decide to extend/modify this project + share the result to a friend.

To deploy:

1. Modify the [autovars](./variables.auto.tfvars) and set `start_remote=true`
1. `terraform apply`
1. Done!

So what it will do is that it will:

1. Build a docker image using the same [docker image module](./module/docker-image) as you used for the local deployment
1. Push the image to a newly created private [*E*lastic *C*ontainer *R*egistry (ECR)](./module/aws-ecs-lb/ecr.tf)
1. Create a [ecs cluster](./module/aws-ecs-lb/ecs.tf)
1. Create a task definition, which uses the docker image you just pushed to ECR
1. Deploy the task definition to one (or more) ECS services, as defined in the [deployments configurations](./main.tf)

You can now configure the services and play around with different healthcheck, timeouts, turn the different heathchecks on and off and investigate the results.

After you're done for the day _remember to run `terraform destroy`_ so that you don't spend more money than you need to.
All of these services are very cheap, but it's not free.
