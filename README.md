# AWS infrastructure for computational biology

## Description

This repository contains infrastructure-as-a-code in Terraform for executing computational
jobs with AWS Batch submitted with Nextflow.

This repository provisions the AWS infrastructure for basic computational 
biology operations. It creates a small basic instance for a user to login, file 
downloads and uploads and for running nextflow, and all necessary AWS resources for 
AWS Batch job executions of nextflow processes.

Terraform version: 0.13.4

# Before initiation of terraform 

We assume the AWS root account and IAM user with programmic access are created.

Before initiating terraform modify the following:
 
*   Add your AWS credentials to `~/.aws/credentials` and
`~/.aws/config`, or run 
```
aws configure
``` 
  and add your key, secret key, region and output format(json).

*   Create a key-pair in EC2 service `<KEY.PAIR>` 
(Go to "Services" - "EC2" - "Network and Security" - "Key Pairs")

*   Change the account name, AWS account ID, and region in `terraform.tfvars` 
*   Change terraform bucket name in `setup-tf-bucket.sh` -  this is where terraform will store the state of your AWS infrastructure.
*   Change profile and terraform bucket name in `main.tf`
*   Change the `KEY.PAIR` to yours in `instances.tf` and `compute-env/ami.tf` 

## Initiating infrastructure


1. Set-up terraform bucket where terraform state will be stored

```
. setup-tf-bucket.sh
```

2. Initialize terraform:

```
terraform init
```


## Apply new changes to infrastructure

1. Check for the changes to be applied
```
$ terraform plan
```

2. If the check is consistent with expected changes, apply the changes:
```
$ terraform apply
```


## Important follow-up steps and considerations

*   Upon first creation of Compute environment, EC2 instance will be created and 
started. Make sure to login to AWS console, go to EC2 - Instances and Stop the 
running instance, but do not terminate it! 

*   You might want to fix the ami ID that was used to create the basic instance. 
See "Created resources:Basic Instance" below

*   For compute environment for Nextflow an AMI with ~1000G root volume is required.
Such AMI is created by first getting latest public ECS optimized AMI, using 
this AMI to create EC2 instance `base-batch-ami` with added necessary root volume of 1000G, and 
then creating AMI `base_batch_nf_ami` based on that instance. This means that there will be an instance 
created in your AWS with the name "base-batch-ami" which serves merely as an ami.
You can avoid this by removing `base_batch_nf_ami` from terraform-managed resources,

```
terraform state rm 'aws_ami_from_instance.base_batch_nf_ami'
```

then deleting (or commenting) all code in `compute-env/ami.tf`, and in 
`compute-env/batch.tf` replacing 

```
image_id = aws_ami_from_instance.base_batch_nf_ami.id 
```
with

```
image_id = "ami-<YOUR_AMI_ID>"
```

You can find your AMI ID in AWS console in  Services - EC2 - Images - AMIs.


# Created resources:

## Compute environment

 Compute environment contains a collection of resources necessary for execution of 
Jobs in AWS Batch. All the relevant resources are defined in `compute_env/`.

### Roles and Policies: `compute_env/aim.tf`

 The resources define the rules of communication between AWS Batch and AWS ECS 
(Amazon Elastic Container Service (ECS) is a container orchestration service).

For that we will need to create a "Role" that can be assumed by AWS Batch and a 
"Role" assumed by ECS to interact with other services and resources. 

"Roles" will need to have "Policies" attached to them, describing the types of 
actions these roles can perform on services and resources.

*   `compute_env/aws_policies/` contains json template files for defining Roles in AWS.
These template files are used in `compute_env/aim.tf` during the creation of 
IAM Role resources.

List of created resources:

*   `aws_iam_role.ecs_instance_role` - ECS role
*   `aws_iam_role.aws_batch_service_role` - Batch role
*   `aws_iam_instance_profile.ecs_instance_profile` - ECS instance profile
*   `aws_iam_role_policy_attachment` - 3 policy attachment for ECS role and 1 policy for Batch role.

### AMI

For Nextflow compute environment an AMI with ~1000G root volume is required.
Such AMI is created by first getting latest public ECS optimized AMI, using 
this AMI to create EC2 instance `base-batch-ami` with added necessary root volume of 1000G, and 
then creating AMI `base_batch_nf_ami` based on that instance. This means that there will be an instance 
created in your AWS with the name "base-batch-ami" which serves merely as an ami.

List of created resources:

*   `aws_network_interface` - a default resource. This isn't really a creation, as your
account has a default interface assigned to it from a start. This is just getting the
ID of this resource to use it in instance creation

*   `aws_instance.base_batch_nf` - instance with 1000Gb root volume
*   `aws_ami_from_instance.base_batch_nf_ami` - AMI based on the instance above.

### Note on AMI creation for compute environemnt

Keeping an extra instance which is only used for AMI, can lead to additional 
costs (though not large). 
You can avoid this by removing `base_batch_nf_ami` from terraform-managed resources,

```
terraform state rm 'aws_ami_from_instance.base_batch_nf_ami'
```

then deleting (or commenting) all code in `compute-env/ami.tf`, and in 
`compute-env/batch.tf` replacing 

```
image_id = aws_ami_from_instance.base_batch_nf_ami.id 
```
with

```
image_id = "ami-<YOUR_AMI_ID>"
```

This will remove all AMI associated resources, but keep the AMI itself (because you uncoupled it).

You can find your AMI ID in AWS console in  Services - EC2 - Images - AMIs.



### Batch

AWS Batch is used to orchestrate computational jobs and assign necessary resources. 
This is where the definition of your compute environment is - in `compute-env/batch.tf`.

Together with the compute environment we will also define queues. We will create
two queues with high and low priority - these queues can be used to prioritize the jobs that
you are submitting. If you don't care, you can just assign all jobs to the same queue. 
 

List of created resources:

*   `aws_default_subnet` - a default resource. This isn't really a creation, just getting 
an ID to use for computational environemnt creation.
*   `aws_security_group` -  a general security group for the compute environment
*   `aws_batch_compute_environment`  - the actual compute environemnt. Here you can 
specify the types of instances that your compute environemnt should use (here just specifies `m5.2xlarge`),
maximum vcpus, min vcpus and the type of instances "SPOT" or "EC2" (by default "EC2"). 
*   two of `aws_batch_job_queue` - `high_priority` and `low_priority`


### Important considerations on parameters in compute environment

*   Please, read again the note on the use of AMI in the creation of compute environemnt above
*   Resource `aws_batch_job_queue` depends on `aws_batch_compute_environment`, which means 
that is you make a change to compute environment that requires it's destruction and re-creation, 
you will need to first remove the queue resource, apply the destruction of queues, then apply your
change to compute environemnt and add back the queues. 
*   Parameter `desired_vcpus = 16` is changed automatically by batch to `desired_vcpus = 0` 
when jobs are executed. So you will often see
that terraform informs you that it will perform a change to compute environemnt, even when you 
didn't actually change anything:
```
> terraform plan

...
 # aws_batch_compute_environment.genomics will be updated in-place

...
          ~ desired_vcpus      = 0 -> 16
...

Plan: 0 to add, 1 to change, 0 to destroy.
...


```
Just ignore this message and proceed with your changes.



## Basic instance

  Basic instance of type `t2.micro` with ssh access is created. 
This instance is meant for only file uploads/downloads and submitting jobs to AWS Batch.

*  *Operating system:* Ubuntu
*  *Root volume*: 30Gb
*  *EBS volume*: 100Gb - additional volume for data - can be mounted to other instances too

### NOTE: Basic instance AMI

Upon creation of instances, terraform will search publicly available images  (AMIs)
with ubuntu, choose the latest, and use it's AMI to create your basic instance.

With this approach, every time a newer AMI comes out, terraform will try to 
re-create your instance using the new AMI, resulting in the loss of all 
installations in your instance. To void this, after the creation of 
the instance, record it's AMI (look at the terraform logs - it will list there 
an actual AMI that was used for the creation), open `instances.tf`, and replace

```
ami = data.aws_ami.ubuntu_2004.id
```
with 
```
ami = "ami-<YOUR_AMI_ID>"
```

### VPC

 Your account has a default VPC assigned to it, so this resource isn't actually created,
but rather it's ID is fetched. This resource is needed to create a security group.

 
### Security group 

  Security group `allow_ssh` is created. This security group is needed to allow ssh connection
to the basic instance.


# Optional resources

## S3 Buckets

In `s3.tf` is provided a code to create a secure bucket. To create a bucket, uncomment the code
and replace desired bucket name and resource name.

## IAM Users

In `users.tf` is the code to create IAM users and asign policies. Note that actual
user names and user-policy pairs are defined in `terraform.tfvars`.

If you need to assign a user a custom policy, you first need to create a policy (
either via terraform or in the console) and then use policy's ARN in `terraform.tfvars`.

NOTE: Don't try to manage your own user through terraform - you might accidentally 
delete your own user, and will have to re-create it through the console

NOTE 2: To grant Console access and Programmatic access you still need to go to aws
console, go to Services - IAM - Users, selectcreated user an choose the access types.
You also need to manually create the keys for that user. 


 



