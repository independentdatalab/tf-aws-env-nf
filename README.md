# AWS infrastructure for computational biology

## Description

This repository contains infrastructure-as-a-code in Terraform for executing computational
jobs with AWS Batch submitted with Nextflow.

This repository provisions the AWS infrastructure for basic computational 
biology operations. It creates all necessary AWS resources for 
AWS Batch job executions of nextflow processes as well as a small basic instance for a user to login, to
download and upload files and to run nextflow.

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

*   Login to your AWS console, and create a key-pair in EC2 service `<KEY.PAIR>` 
(Go to "Services" - "EC2" - "Network and Security" - "Key Pairs"). This key-pair identifies a user,
so I typically use `f.lastname` as the name. In order to later use `ssh` to login to your 
instance, download your key-pair and store it locally. 

*   Modify the file `terraform.tfvars`: Change the account name (choose one - it will be used as an alias to your account), AWS account ID (numeric ID), and region.
*   In `setup-tf-bucket.sh` modify  terraform bucket name -  this is where terraform will store the state of your AWS infrastructure. The name has to be unique across all AWS buckets.
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


## Apply new changes to infrastructure in 2 steps:

### Step 1: Create initial infrastructure and batch instance

This step will prepare all initial resources that are needed to configure batch.
Most importantly, it will create AWS EC2 instance that will be used for creation
of custom nextflow AMI. This instance will have additional storage attached to it, 
and it will have a miniconda and awscli installed.

1. Check for the changes to be applied
```
$ terraform plan
```

When you do it the first time, you will have some 15 resources that will be added.

2. If the check is consistent with expected changes, apply the changes:
```
$ terraform apply
```

### Step 2: Wait! and then create the rest of the infrastructure

Even after terraform finishes creating all the resources above, you need to wait
for about 15 minutes to make sure that teh instance that you created for 
AWS Batch finished installing all the scripts. While you are waiting:

1. Open `compute-env/ami.tf` and uncomment the last part by deleting the lines:

```
/*
//UNCOMMENT AFTER THE INSTANCE ABOVE CREATED
```

and 

```
//UNCOMMENT AFTER THE INSTANCE ABOVE CREATED
*/
```

2. Open `compute-env/batch.tf` and uncomment the last part by removing the follwoing lines:

```
/*
// UNCOMMENT AFTER THE INSTANCE IN ami.tf CREATED
```

and

```
// UNCOMMENT AFTER THE INSTANCE IN ami.tf CREATED
*/
```

3. If some 15 minutes have already passed, you can run terraform apply to apply
new changes. If you want to be 100% sure that the installation was complete,
you can connect to the instance using ssh. To do so, login to AWS console in
your browser, select Service -> EC2. In the list of instances find the one called
`base-batch-ami`, right-click on it and select "Connect". You will find instructions
there. Once you have ssh-ed into the instance, run:

```
systemctl status cloud-final.service
```

If you see:
```
 Active: active (exited)
```
Then the script is complete. You can also check if the installation is good by running:

```
$ ./miniconda/bin/aws --version
aws-cli/1.19.79 Python/3.8.5 Linux/4.14.231-173.361.amzn2.x86_64 botocore/1.20.79
```

if all is in order, feel free to run 

```
terraform apply
```

That's it. All necessary resources are created and you can now use in your
nextflow pipelines

```
process{
  executor = 'awsbatch'
}
```

My typical `aws.config` is provided below.

##

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

### Login in to your basic instance

In order to ssh to your instancem you need to have a public DNS of your instance.
You can get by login in to AWS console, navigating to EC2 service, Instances,
selecting your instance in the list and pressing "Connect" button - it will pop-up
a window with connecting instructions. 

Alternatively, you can use aws cli to get the public DNS:
```
aws ec2 describe-instances | grep "PublicDnsName"
```

It should look something like this: ec2-X-X-X-X.region.compute.amazonaws.com.

If you alrready downloaded your `<KEY.PAIR> `, then ssh to your instance:

```
ssh -i "/path/to/keypair/<KEY.PAIR>" ubuntu@ec2-X-X-X-X.region.compute.amazonaws.com
```

You will need to install all the necessary tools on your instance, including Nextflow.


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


 
## Important follow-up steps and considerations

*   Upon first creation of Compute environment, EC2 instance will be created and 
started. Make sure to login to AWS console, go to EC2 - Instances and Stop the 
running instance, but do not terminate it! 

*   You might want to fix the ami ID that was used to create the basic instance. 
See "Created resources:Basic Instance" above

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


## My typical aws.config for Nextflow pipelines

For running the pipelines on AWS you will need docker images with the tools required
by your pipeline. I personally prefer to have one tool per image whenever possible.
All my images are stored on ECR at the moment, and I am slowly migrating to 
docker hub. 

So here is my typical aws.config for running nextflow:

`conf/aws.config`
```
params {
  config_profile_name = 'AWSBATCH'
  config_profile_description = 'AWSBATCH Cloud Profile'
  config_profile_contact = 'Independent Data Lab'
  config_profile_url = 'https://aws.amazon.com/de/batch/'
}

workDir = 's3://nf-work-bucket/nf-ribo'

process{
  executor = 'awsbatch'
  // Per-process configuration
  withName:fastqc {
      container = '915458310522.dkr.ecr.eu-central-1.amazonaws.com/batch/fastqc'
      cpus = 2
      memory = '16GB'
      queue = 'high_priority'
    }
  withName:cutadapt {
      container = '915458310522.dkr.ecr.eu-central-1.amazonaws.com/batch/cutadapt'
      cpus = 8
      memory = '30GB'
      queue = 'high_priority'
    }

  ...< AND SO ON >...

  withName:multiqc {
      container = '915458310522.dkr.ecr.eu-central-1.amazonaws.com/batch/multiqc'
      cpus = 8
      memory = '30GB'
      queue = 'high_priority'
    }
}

docker {
    enabled = true
}

```

In the nextflow.config you need to add your new profile:

```
profiles {
  awsbatch { includeConfig 'conf/aws.config' }
}
```



And I run my pipelines like this:

```
nextflow run main.nf -profile awsbatch
```


