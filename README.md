# betunfair

![Elixir](https://img.shields.io/badge/elixir-%234B275F.svg?style=for-the-badge&logo=elixir&logoColor=white)

## Base functionality

- The base functionality is present in the betunfair/lib directory.
- **Version has to be 1.9.1 or superior**, in case of faillure the mix.exs can be changed.

```bash
cd betunfair
iex -S mix
```

## Tests

- Tests can be found in betunfair_test.exs file, in the betunfair/test directory. They can be executed by using the next command:

```bash
cd betunfair
mix test --trace
```

## Scalability

### Docker

- In order to make the application scalable, we created a Docker Image to use it on the Kubernetes deployment.
- The image copies the application into the container and starts the application.
- The container has the environment variable RELEASE_COOKIE, in order to connect the nodes together. Therefore, they need to share the same Erlang Cookie.

```bash
cd betunfair
docker build -t pss-image . --file Dockerfile --no-cache
```

- This command will build the image 'pss-image' locally.

### Kubernetes

- Kubernetes allows to scale the application automatatically.
- To create a number of pods in the clúster running the application, we created a Deployment specifying the image previously created for each pod.
- The number of 'replicas' is 3. Kubernetes will try to always mantain the number of 'replicas' available.
- If one of the pods have failed, Kubernetes will automatically restart the pod to match the 'replicas'.
- Each 'replica', shares the same environment variable named RELEASE_COOKIE, in order to connect the nodes together.
- The application exposes the port 4369.
- To expose the application, we created a Kubernetes Service that exposes port 80 and redirects the traffic to the application port (4369). The traffic is automatically redirected to one of the 'replicas' running the application.

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### Phoenix (TODO)

- In order to access to the cluster exposed by Kubernetes, the fuctions must be exposed a REST API.
