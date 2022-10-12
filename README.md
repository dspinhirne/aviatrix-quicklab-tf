# Overview
This repo contains a set of Terraform configurations that are designed to enable the quick deployment of Aviatrix lab scenarios. Above all, this is an experiment 
to help me determine what was possible in native TF.

As this is meant to enable lab work, deployments are restricted to a single region per CSP.

For the sake of brevity within configuration files, certain assumptions are made about the setup of various Aviatrix features. 
If your situation requires customization beyond what is provided within the input variables, then the best approach is to either deploy
components manually atop a vanilla base setup or to provide additional terraform configuration files. Keep in mind that if you manually 
deploy components (or use additional TF files), then you destroy these additional components prior to destroying the base lab.


## Summary of Steps

1. Deploy Controller
2. Setup Access Accounts
3. Deploy lab


# Deploying Aviatrix Controller

## AWS
### Prerequisites

1. Create an AWS credentials file for storing API credentials. Ideal location is in your home directory (.aws/credentials).
2. Create an AWS keypair (if you don't already have one available).
3. Install Python3

### Installing Python
This section only needs to be completed once. It will install a python virtual env that is required to build the controller.

From the top-level directory:
    cd avx-control-aws
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
    cd ../

### Create terraform.tfvars
This section only needs to be completed once. From the top-level directory:
    cd avx-control-aws
    touch terraform.tfvars

Store your personalized data in this file. Sample below:

    credentials_file = "~/.aws/credentials"
    admin_email = "user@localdomain"   // controller will email you here
    admin_password = "changeme"        // login password for user 'admin'
    access_account_name = "changeme"    // label for your aws account within the controller
    access_account_id = "xxxx"          // aws account number
    region = "us-east-1"               // change if you want
    keypair = "changeme"               // your keypair name
    create_iam_roles = false           // set true if this is your first run
    controller_version = "latest"
    controller_license_type = "BYOL"  
    controller_license = "xxxxx"       
    permitted_prefixes = ["0.0.0.0/0"] // probably want to set this to your own ip as x.x.x.x/y
    name_prefix = "avx-lab"            // a prefix for stuff deployed by controller
    termination_protection = false     // optional. this is the default
    deploy_copilot = true              // optional. this is the default

### Create provider.tf
This section only needs to be completed once. From the top-level directory:
    cd avx-control-aws
    touch provider.tf

Store your personalized data in this file. Sample below:

    terraform {
    required_providers {
        aviatrix = {
        source = "AviatrixSystems/aviatrix"
        }
        aws = {
        source  = "hashicorp/aws"
        }
    }
    }

    provider "aws" {
        region                   = var.region
        shared_credentials_files = ["~/.aws/credentials"]
    }



### Deploying
From the top-level directory:

    cd avx-control-aws
    source venv/bin/activate
    terraform init
    terraform apply
    deactivate
    cd ../

At the conclusion of the build, Terraform will output the commands for setting the environment variables needed to work with the controller. The output will be similar to the following:

    export AVIATRIX_CONTROLLER_IP=x.x.x.x
    export AVIATRIX_USERNAME=admin
    export AVIATRIX_PASSWORD=xxxx

You need to copy this output into any terminals from which you run Terraform.

### Destroying
From the top-level directory:

    cd avx-control-aws
    source venv/bin/activate
    terraform destroy -var-file="../terraform.tfvars"
    deactivate

Note that there is a bug that prevents Terraform from destroying the VPCs created by the deployer. You will need to manually destroy this.



# Setting Up Access Accounts

## Create terraform.tfvars
This section only needs to be completed once, and only if you want to use Azure. From the top-level directory:
    cd avx-access-accounts
    touch terraform.tfvars

Store your personalized data in this file. Sample below:

    aws_accounts = {
    azure_accounts = {
        "azure-lab": {
            sub_id: "xxxx"     //change me
            dir_id: "xxxx"     //change me
            app_id: "xxxx"     //change me
            app_key: "xxxx"   //change me
        }
    }


## Applying the Configuration
This step should be run once per controller deploy. It will skip accounts that already exist in the controller. From the top-level directory:

    cd avx-access-accounts
    terraform init
    terraform apply




# Deploying the remainder of the lab.

## Prerequisites

1. An existing controller.
2. Create an AWS credentials file for storing API credentials. Ideal location is in your home directory (.aws/credentials).
3. Create an AWS keypair (if you don't already have one available).

## Create terraform.tfvars
This section only needs to be completed once. From the top-level directory:
    cd avx-control-aws
    touch terraform.tfvars

This file will contain the structure for your lab setup. Details below


## Create provider.tf
This section only needs to be completed once. From the top-level directory:
    cd avx-control-aws
    touch provider.tf

Store your personalized data in this file. Sample below:

    terraform {
        required_providers {
            aviatrix = {
                source = "AviatrixSystems/aviatrix"
            }
            aws = {
                source  = "hashicorp/aws"
            }
            /*
            # uncomment this section if you want to use Azure
            azurerm = {
                source  = "hashicorp/azurerm"
            }
            */
        }
    }

    /*
    # uncomment this if you dont export env variables
    provider "aviatrix" {
        controller_ip           = "x.x.x.x"
        username                = "admin"
        password                = "xxxxxxx"
    }
    */

    provider "aws" {
        region                   = var.csps.aws.region
        shared_credentials_files = ["~/.aws/credentials"]
    }

    /*
    provider "azurerm" {
        tenant_id       = var.csps.azure.dir_id
        subscription_id = var.csps.azure.sub_id
        client_id       = var.csps.azure.app_id
        client_secret   = var.csps.azure.app_key
        features {}
    }
    */


## Deploying
Once the controller has been deployed and environmental variables set, deploying the remainder of the setup is simply a matter of
customizing your input variables file to suit the lab you wish to deploy. 

From the top-level directory:

    terraform init
    terraform apply


## Variables
The following describes the variables supported within the terraform.tf file. See sample file.


### Inbound Access
Inbound access to any lab components is controlled via the following:

    # defines inbound rules for security groups. replace with your public ip
    permitted_prefixes = ["x.x.x.x/32"]


### Access Accounts
These define settings for any access accounts you have added to the controller. These are also used in provider.tf. Only 1 account per CSP. 
Only 1 region per CSP. Only AWS and Azure supported. You must define at least 1 CSP.

    csps = {
        aws = {
            account: "aws-lab"    // the access account name within the controller
            region: "us-east-1"

        }
        azure = {
            account: "azure-lab" // the access account name within the controller
            region: "East US"
            sub_id: "xxxx"     //change me
            dir_id: "xxxx"     //change me
            app_id: "xxxx"     //change me
            app_key: "xxxx"    //change me
        }
    }

### Gateway Sizes
This is optional and sets the default gateway sizes used in the lab. You only need to set this if you want to change the defaults. Defaults are shown below.

    gw_sizes = {
    aws: {sm: "t3.small", lg: "c5.xlarge"}
    azure: {sm: "Standard_B1ms", lg: "Standard_B1ms"}
    }

The small size is used for non HPE setups. The large size is used for HPE.


### Cisco CSR settings
This is optional and only needed if you want to use a CSR. It defines the instance size and AMI for Cisco CSR in AWS. 
AMIs need to be defined per region. The default provides an AMI for us-east-1.

    aws_csr_settings = {
        username = "admin"
        password = "xxxx"   //change me
        keypair = "xxxx"    //change me to an existing kp
        size = "t2.medium"
        amis = {
            "us-east-1" = "ami-06673acad74a19508"
        }
    }

### Transit Gateways
These are defined within a 'transits' variable. Within this variable, you will define all of your transit gateways. 
Example below showing a single transit with config options.

    transits = {
        transit1 = {                        // this is the name of your gateway
            disabled: false                 // causes TF to skip over this gw definition. setting true will cause the gw to be removed.
            csp: "aws"                      // required. must be either aws or azure. requires that you have defined an account in the csp
            prefix: "10.1.0.0/23"           // defines the address space for the vpc to be created for the transit. an aviatrix transit vpc will be created automatically
            size: null                      // allows you to override the default gw size
            hpe: false                      // enables hpe using the last 2 /26 ranges of the vpc
            enable_ha: false                // enables ha and deploys the ha gw
            bgp_asn: null                   // sets local bgp asn
            enable_transit_firenet: false   // enables firenet and enables the vpc to reflect this
            enable_segmentation: false      // enables network segmentation
        }
    }

### Transit Peering
Defines peerings between Transit gateways. Use the gw names defined in your transit config.

    transit_peerings = [
        {peer1:"transit1", peer2:"transit2"},
    ]


### Spoke Gateways
These are defined within a 'spokes' variable. Within this variable, you will define all of your spoke gateways. 
Example below showing a single spoke with config options.

    spokes = {
        spoke1: {
            disabled: false                 // causes TF to skip over this gw definition. setting true will cause the gw to be removed.
            csp: "aws"                      // required. must be either aws or azure. requires that you have defined an account in the csp
            prefix: "10.1.2.0/24"           // defines the address space for the vpc to be created for the transit. an aviatrix vpc will be created automatically
            size: null                      // allows you to override the default gw size
            hpe: false                      // enables hpe using the last 2 /26 ranges of the vpc
            enable_ha: false                // enables ha and deploys the ha gw
            enable_bgp: false               // enables bgp
            bgp_asn: null                   // sets local bgp asn
        }    
    }


### Spoke - Transit Attachments
Defines attachments. Use the gw names defined in your transit and spoke definitions.

    spoke_transit_attachments = [
        //{spoke: "spoke2", transit: "transit1"},
    ]

### Network Segmentation
Defines network segmentation. Example showing 3 domains and their attachments.

    net_seg_domains = ["shared", "prod", "dev"]     // a list of domains to create
    net_seg_connection_policies = [
        {d1: "shared", d2: "prod"},                 // connection policies
        {d1: "shared", d2: "dev"},
    ]
    net_seg_associations = {                        // associations. use the netwwork domain as the key, and spoke/transit names per your definitions.
        "shared": {transit: "transit1", spoke: "spoke1"}
        "prod": {transit: "transit2", spoke: "spoke2"}
    }


### Gateway External Connections
These will create quick setups for simulating external connections. Sample with options below.

    external_connections = {
        "transit1_csr" = {                  // this is the name of this connection
            disabled: false                 // causes TF to skip over this gw definition. setting true will cause the gw to be removed.
            gw_type: "transit"              // must be either spoke or transit. example showing a transit
            gw_name: "transit1"             // the name of the spoke or transit gw. example showing a transit
            local_bgp_asn: null             // optional. prefers asn defined on gw if one is defined there. if not in either place, then uses static routing
            gre_only: false                 // only valid for connections to transit gw
            external_peer: {
                type: "aws_csr"             // the type of setup to use. only supports aws_vgw or aws_csr for now
                prefix: "10.100.2.0/24"     // the address space of the vpc to be created. an aviatrix vpc will be created by default
                bgp_asn: null               // the remote bgp asn. if not provided then static routing used.
            }
            tun1_prefix: "169.254.0.240/30"     // optional. this is only needed if you want to customize tunnel address space.
            tun2_prefix: "169.254.0.244/30"
            tun1_prefix_ha: "169.254.0.248/30"
            tun2_prefix_ha: "169.254.0.252/30"
        }
    }

### Site to Cloud
These will create quick setups for simulating on-prem environments. Sample below with options

    s2c = {
        "spoke1_dc1" = {
            disabled = false                // this is the name of this connection
            gw_type: "spoke"                // must be either spoke or transit. example showing a spoke
            gw_name: "spoke2"               // the name of the spoke or transit gw. example showing a spoke
            external_peer: {
                type: "aws_vgw"             // the type of setup to use. only supports aws_vgw or aws_csr for now
                prefix: "10.100.1.0/24"     // the address space of the vpc to be created. an aviatrix vpc will be created by default
            }
            unmapped: {                     // creates an unmapped connection with address space defined for both cloud side and remote side
                cloud_prefix: "10.0.0.0/16"
                site_prefix:"10.10.0.0/24"
            }
            mapped: {                       // creates a mapped connection with real/virtual address space defined for both cloud side and remote side
                cloud_prefix: "10.0.0.0/16"
                cloud_virtual: "10.100.0.0/16"
                site_prefix:"10.10.0.0/24"
                site_virtual:"10.200.0.0/24"
            }
        }
    }

