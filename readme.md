Acme corp. has forwarded the idea of futher developing the CI. Through the utilization of Kubernetes along with their current automation the deployment for their acme application will provide a great level of control for scalability, testing and deployments.   

## Requirements

Add CircleCI Environemnt Variables for AWS_ACCESS_KEY_ID, AWS_DEFAULT_REGION, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN. Following that update the aws credentials. 

## Standing Infastructure

There are two methods available to stand the infastrucuture. Manual or Automated.

##### Automated
Standing all of the infastructure is automated by the use of a make file located at [/Makefile](/Makefile). Simply run the command `make all-up`.

This automation for standing the infastructure uses various aws queries and terraform outs to perform some trickery to obtain the appropriated information then applying them to the file. 
```
apply-vars:
	sed -i "/--state s3:\/\/rmit-kops-state-/c\          kops export kubecfg rmit.k8s.local --state s3:\/\/rmit-kops-state-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )" .circleci/config.yml
	sed -i "/ECR:/c\      ECR: $(shell  cd ./environment/infra && terraform output ecr_url | cut -d "/" -f 1 )" .circleci/config.yml
	sed -i "/--backend-config/c\	terraform init --backend-config=\"key=state/"$$"{ENV}.tfstate\" --backend-config=\"dynamodb_table=RMIT-locktable-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )\" --backend-config=\"bucket=rmit-tfstate-$(shell  cd ./environment/infra && terraform output state_bucket_name | cut -d "-" -f 3 )\"" infra/Makefile
	sed -i "/vpc_id/c\vpc_id = \"$(shell aws ec2 describe-vpcs --filter Name=tag:Name,Values=rmit.k8s.local --query Vpcs[].VpcId --output text)\"" infra/terraform.tfvars
	sed -i "/subnet_ids/c\subnet_ids = [ \"$(shell aws ec2 describe-subnets --filter Name=tag:Name,Values=us-east-1a.rmit.k8s.local --query Subnets[].SubnetId --output text)\", \"$(shell aws ec2 describe-subnets --filter Name=tag:Name,Values=us-east-1b.rmit.k8s.local --query Subnets[].SubnetId --output text)\" ]" infra/terraform.tfvars


all-up: 
	cd environment && make up
	cd environment && make kube-up
	make apply-vars
```

##### Manual
The infastruture must be stood in a specific order due to dependencies. 
1. Stand the environment in [/environment/infra/](/environment) by using `make up`
2. Stand the kube cluster in [/environment/infra/](/environment) by using `make kube-up`
3. Standing the database environment requires additional steps.
   1. The content of the make file in [infra](/infra/Makefile) must be altered by replacing both `--backend-config=` with the bucket and state deployed by using the [environment](/environment) folder. To obtain the correct details it is best to use `terraform output` in the [/environment/infra/](/environment/infra/) folder.
   ![DB_APPLY_VPC](/img/01_Stand_DB.png)

   2. Open up the AWS Console and locate the generated VPC labeled rmit.k8s.local and apply the subnets and vpc ids to the [infra/Makefile](infra/Makefile) file.
   ![DB_APPLY_VPC](/img/00_Stand_DB.png)

   3. Stand the db environment by deciding on deploying a production or testing then prefix the `make init` and `make up` commands with that environment name. Example `ENV=test make up`.


## HELM Scaffolding
The helm package will contain code for the environment the app should be deployed into. Here is an overview of the files located in [/helm/acme](/helm/acme):
- The [values.yaml](/helm/values) contains variables. Noteably the variables image and dbhost will be overwritten in the deployment pipeline in order to better handle the automation.
  - Stores variables
  - Some variables are intentionally left invalid. They are overwritten by the CircleCI pipeline. 
- The [Chart.yaml](/helm/acme/Chart.yaml) contains what version of api to use, application name, description and versions.
  - Porvides basic information 
- The [deployment](/helm/acme/templates/deployment.yml) configures the deployment variables/environment for applications. 
  - This file stands the ec2 instances via auto scale
  - Pull docker image from ECR
  - Passes environment variables when executed through the CircleCI pipeline.
  - Has port 3000 open
- The [service.yml](/helm/acme/templates/service.yml) configures the load balancer. The load balancer redirects traffic to the instances generated deployment yaml. 
  - This file stands a load balancer
  - Has port 80 open
  - Redirects to target group of port 3000

## Test Environment

##### CircleCI Integration and Deployment 

Passing variables through the environment safely requires the use of CircleCI environment variables. Just like how you added the AWS variables to CircleCI create additional ones. Refer to screenshot.
![ENV_VAR](/img/Task_B-B_01.PNG)  

The package job handles variables the docker image. It stores the image onto the ECR earlier stood up and then stores the url of the image inside of the artifacts folder, this folder is set to be persistant and usable when called.  

Following this update the [.circleci/config.yml](/.circleci/config.yml) update line 24 with the new bucket id. 

Ensure that the environment variable is set to test for this job by applying `ENV: test` to the jobs environment.

The CircleCI pipeline configuration exports the database endpoint and the image as variables this is done through. Additionaly these variables are applied to `helm install` by using the `--set` parmeter.
```yaml 
kubectl create namespace $ENV
cd infra; make init; 
make up; 
export dbhost_endpoint=$(terraform output endpoint); cd ..;

export docker_image="$(cat ./artifacts/image.txt)"

helm upgrade acme artifacts/acme-*.tgz -i --wait -n $ENV --set dbhost=${dbhost_endpoint},image=${docker_image},dbname=$db_name,dbuser=$db_user,dbpass=$db_pass

kubectl exec deployment/acme -n ${ENV} -- node_modules/.bin/sequelize db:migrate 

helm list -n $ENV
kubectl get services -n $ENV
kubectl get pods -n $ENV
```
So What this does is:
  - Create a namespace 
  - Deploy a database
  - Run database migration
  - Deploy HELM Chart to the Kubernetes cluster
Here is some screen shots of it in action.

![ENV_VAR](/img/Task_C_01.png)  

![ENV_VAR](/img/Task_C_02.png)

![ENV_VAR](/img/Task_C_03.png)

##### End to End Testing

End to end testing is performed using the CircleCI file located at [/.circleci/config.yml](/.circleci/config.yml). When the job e2e is performed it will be done so utilizing the following.

The predefined enviroment variables are altered to utilize the CircleCI variables, this includes the an extra addition variables for ENV.

```
    environment:
      QAW_HEADLESS: true
      DB_USERNAME: $db_user
      DB_PASSWORD: $db_pass
      DB_NAME: servian
      DB_HOSTNAME: localhost
      ENV: test
```

To being the E2E a requirement is to alter teh DB_HOSTNAME and grab it. This is done through `terraform output endpoint` with the help of the remote backend. Th get the correct ELB endpoint `kubectl` is used. 
```
cd infra; make init; export DB_HOSTNAME=$(terraform output endpoint); cd ..;
export ENDPOINT="http://$(kubectl get service/acme -n test -o=yaml | grep hostname | cut -d: -f2- | sed -e 's/^[ \t]*//'):80"
echo $ENDPOINT
echo $DB_HOSTNAME

cd src
npm run start & 
npx wait-on $ENDPOINT
npm run test-e2e
```
When this job is run the finished output should be as per screenshots below.

![E2E_1](/img/Task_D_01.png)

![E2E_1](/img/Task_D_02.png)


## Production Environment

##### CircleCI Integration and Deployment 

Due to the use of variables to define the enviroment majority of the code can remain the same. The job `deploy-helm-prod` (which is specifically for deploying into production) contains two alterations compared to `deploy-helm-test`.

- Ensure that the environment variable is set to test for this job by applying `ENV: prod` to the jobs environment.
- The `kubectl exec deployment/acme -n ${ENV} -- node_modules/.bin/sequelize db:migrate --environment production` contains the additional parameter `--env production`.

So What this does is:
  - Create a namespace 
  - Deploy a database
  - Run database migration
  - Deploy HELM Chart to the Kubernetes cluster
Here is some screen shots of it in action.

![PROD](/img/Task_E_01.png)  

![PROD](/img/Task_E_02.png)

![PROD](/img/Task_E_03.png)

##### Approval

![APR](/img/Task_F_01.png)


## Clean Up

The makefile in [/Makefile](/Makefile) will handle this. Simplply run `make all-down`

## Running Entire Workflow with Cloudwatch Monitoring

The application of cloudwatch enables viewing logs on AWS Cloudwatch. This is done automatically through a CircleCI job through:
```
  cloudwatch:
    docker:
     - image: cimg/base:2020.01 
    environment:
      ENV: amazon-cloudwatch
    steps:
      - checkout
      - setup-cd
      - run: 
          name: Enabling cloudwatch
          command: |
            kubectl create namespace ${ENV}
            kubectl create configmap cluster-info --from-literal=cluster.name=rmit.k8s.local --from-literal=logs.region=us-east-1 -n ${ENV}
            wget https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluentd/fluentd.yaml
            kubectl apply -f fluentd.yaml
```
Summary | Screenshot
------------ | -------------
New workflow has been initated for all of the created jobs. |![WORKFLOW](/img/Task_G_01.png)

Summary | Screenshot
------------ | -------------
Cloudwatch is enabled... Job is complete - Package Job is complete | ![WORKFLOW](/img/Task_G_02.png) ![WORKFLOW](/img/Task_G_04.png) ![WORKFLOW](/img/Task_G_05.png) 

Summary | Screenshot
------------ | -------------
Kubectl HELM Deployment into Test Enviroment Job is complete - End to end testing is complete | ![WORKFLOW](/img/Task_G_06.png) ![WORKFLOW](/img/Task_G_07.png) 

Summary | Screenshot
------------ | -------------
Approving the stage gate for Deploying to Production Environment | ![WORKFLOW](/img/Task_G_08.png) ![WORKFLOW](/img/Task_G_09.png) ![WORKFLOW](/img/Task_G_10.png)

Summary | Screenshot
------------ | -------------
Checking up on cloud watch | ![WORKFLOW](/img/Task_G_11.png) ![WORKFLOW](/img/Task_G_12.png) ![WORKFLOW](/img/Task_G_13.png) ![WORKFLOW](/img/Task_G_14.png) ![WORKFLOW](/img/Task_G_16.png)

Summary | Screenshot
------------ | -------------
Kube has deployed to Production Environment | ![WORKFLOW](/img/Task_G_15.png) ![WORKFLOW](/img/Task_G_21.png)

Summary | Screenshot
------------ | -------------
Verifying AWS deployment | ![WORKFLOW](/img/Task_G_17.png) ![WORKFLOW](/img/Task_G_18.png) ![WORKFLOW](/img/Task_G_19.png) ![WORKFLOW](/img/Task_G_20.png)

Summary | Screenshot
------------ | -------------
Approving Stage Gate for Clean Up Job |   ![WORKFLOW](/img/Task_G_22.png) ![WORKFLOW](/img/Task_G_23.png)

Summary | Screenshot
------------ | -------------
Now that the cleanup job is complete lets verify with AWS |   ![WORKFLOW](/img/Task_G_24.png) ![WORKFLOW](/img/Task_G_26.png) ![WORKFLOW](/img/Task_G_27.png) ![WORKFLOW](/img/Task_G_28.png)

## Utilization of CircleCI and Github
Due to CircleCI credit issue majority of the work was completed with a personal repository. Here are some screenshots of the branchs and CI.

![/img/CircleCI.png](/img/CircleCI.png)

![/img/Github_01.png](/img/Github_01.png)


## Cleanup
Cleanup is automated through CircleCI. There is also commands within the [/Makefile](/Makefile) available.