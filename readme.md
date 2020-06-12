## Requirements

Add CircleCI Environemnt Variables for AWS_ACCESS_KEY_ID, AWS_DEFAULT_REGION, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN. Following that update the aws credentials. 

#### Standing Infastructure
The infastruture must be stood in a specific order due to dependencies. 



ENV=test make init

subnet_ids = [
  "subnet-062eded0a78f193a2",
  "subnet-045f74398bba4b493"
]
username = "thisistheuser"
password = "123456789"
vpc_id = "vpc-0788d388b46354505"
name = "acme-db"

#### Creating HELM Scaffold
The helm package will contain code for the environment the app should be deployed into. Here is an overview of the files located in [/helm/acme](/helm/acme):
- The [values.yaml](/helm/values) contains variables. Noteably the variables image and dbhost will be overwritten in the deployment pipeline in order to better handle the automation.
- The [Chart.yaml](/helm/acme/Chart.yaml) contains what version of api to use, application name, description and versions.
- The [deployment](/helm/acme/templates/deployment.yml) configures the deployment variables/environment for applications.
- The [service.yml](/helm/acme/templates/service.yml) configures the load balancer.


#### Automation of variable passing
In CircleCI under the package job the handling variables for the image tag and dbhost is done by 



