## Requirements

Add CircleCI Environemnt Variables for AWS_ACCESS_KEY_ID, AWS_DEFAULT_REGION, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN. Following that update the aws credentials. 

#### Standing Infastructure

The infastruture must be stood in a specific order due to dependencies. 
1. Stand the environment in [/environment/infra/](/environment) by using `make up`
2. Stand the kube cluster in [/environment/infra/](/environment) by using `make kube-up`
3. Standing the database environment requires additional steps.
   1. The content of the make file in [infra](/infra/Makefile) must be altered by replacing both `--backend-config=` with the bucket and state deployed by using the [environment](/environment) folder. To obtain the correct details it is best to use `terraform output` in the [/environment/infra/](/environment/infra/) folder.
   ![DB_APPLY_VPC](/img/01_Stand_DB.png)

   2. Open up the AWS Console and locate the generated VPC labeled rmit.k8s.local and apply the subnets and vpc ids to the [infra/Makefile](infra/Makefile) file.
   ![DB_APPLY_VPC](/img/00_Stand_DB.png)

   3. Stand the db environment by deciding on deploying a production or testing then prefix the `make init` and `make up` commands with that environment name. Example `ENV=test make up`.

#### Creating HELM Scaffold
The helm package will contain code for the environment the app should be deployed into. Here is an overview of the files located in [/helm/acme](/helm/acme):
- The [values.yaml](/helm/values) contains variables. Noteably the variables image and dbhost will be overwritten in the deployment pipeline in order to better handle the automation.
- The [Chart.yaml](/helm/acme/Chart.yaml) contains what version of api to use, application name, description and versions.
- The [deployment](/helm/acme/templates/deployment.yml) configures the deployment variables/environment for applications.
- The [service.yml](/helm/acme/templates/service.yml) configures the load balancer.


#### Pipieline 
Things that need to be updated based on the stood infastructure [.circleci/config.yml](/.circleci/config.yml) update line 24 with the new bucket id. 
The CircleCI pipeline configuration exports the database endpoint and the image as variables this is done through.
```yaml 
cd infra; make init; export dbhost_endpoint=$(terraform output endpoint); cd ..;
export docker_image="$(cat ./artifacts/image.txt)"
```
and these variables are applied to deployments by using the `--set` parmeter
```yaml
helm install acme artifacts/acme-*.tgz -i --wait --set dbhost=${dbhost_endpoint} --set image=${docker_image}
```
In CircleCI under the package job the handling variables for the image tag and dbhost is done by 



      - run:
          name: Create Testing Namespace
          command: |
            kubectl create namespace test