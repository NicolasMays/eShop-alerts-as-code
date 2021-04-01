#### Automated Alert Deployment

---

**Basic Scenario**: Local Deployments

Prerequisites: 

- Azure Subscription
- Azure CLI Installed and Logged into your Subscription
- Terraformed Installed: [Terraform: Azure Get Started](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/azure-get-started)
- Create a Resource Group and a Log Analytics workspace 
- Clone the code?

Working Directory:

​	 `/eShop-alerts-as-code/scheduled_query_alert/`

Customer-Focused SLOs are generally comprised of the same components for the same SLO type regardless of the user journey it's describing. If we were to look at an SLO for Availability or Success-Rate the components would be:

- Target, or level of reliability 
- User journey category
- Time window
- Success Criteria 

Consider the eShop on Containers SLO for success-rate for "View Catalog":

` 99.9% of "/catalog" requests in the last 60 mins were successful (HTTP Response Code: 200) as measured at the API Gateway`

We can map different pieces of the SLO to the components listed above:

- Target, or level of reliability &rarr; `99.9%`
- User journey category &rarr; `"/catalog" requests`
- Time window &rarr; `in the last 60 minutes`
- Success Criteria &rarr; `were successful (HTTP Response Code: 200) as measured at the API Gateway`

For another user journey we could reuse the same structure and components for another availability SLO, adjusting the values to reflect the SLOs requirements for the respective user journey. Given this convenience we're presented with the opportunity to not only maintain our SLOs as code, but to deploy the alerts for these SLOs with technology like Terraform or Azure Resource Manager (ARM) Templates.

These next steps explain how to deploy SLO alerts to Azure utilizing terraform. Terraform is an open-source software tool to manage infrastructure as code. 

Get started with Terraform for Azure [here](https://learn.hashicorp.com/collections/terraform/azure-get-started). 

To create alerts for SLOs we want to deploy a collection of `scheduled query rules alert` resources to Azure. Terraform's documentation for this resource can be found [here](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_scheduled_query_rules_alert). However this is the basic structure of the resource.

```
# example scheduled query rules alert
resource "azurerm_monitor_scheduled_query_rules_alert" "example" {
  name                = <alert rule name>
  location            = <resource location>
  resource_group_name = <resource group name>

  action {
    action_group           = [] 
    email_subject          = "Email Header"
    custom_webhook_payload = "{}"
  }
  data_source_id = <Log analytics resource id>
  description    = "<description of the alert>"
  enabled        = true
  query       = <<-QUERY
  	<KQL query describing your alert>
  QUERY
  severity    = 1
  frequency   = 5
  time_window = <time window>
  trigger {
    operator  = "GreaterThan"
    threshold = <threshold>
  }
}
```



In `variables.tf` we have parameterized any fields that will be reused throughout the deployment of these SLOs. This file declares the structure of variables which we provide values for later.

```
# variables.tf
variable "logAnalyticsResourceID" {
    type        = string
    description = "Resource ID of the Log Analytics workspace."
}

variable "logAnalyticsResourceGroupName"{
    type        = string
    description = "Name of Resource Group containing Log Analytics workspace"
}

variable "resourceRegion" {
    type        = string
    default     = "eastus2"
    description = "Location for the resource(s)."
}

variable "alertActionGroups" {
    type        = list(string)
    default     = []
    description = "Action group(s) for the alerts"
}

variable "webHookPayLoad" {
    type        = string
    default     = "{}"
    description = "Custom payload to be sent with the alert"
}

variable "SLOs" {
    type = map(object({
        userJourneyCategory = string, 
        sloCategory         = string,
        sloPercentile       = string,
        sloDescription      = string,
        signalQuery         = string,
        signalSeverity      = string,
        frequency           = number, 
        time_window         = number,
        triggerOperator     = string,
        triggerThreshold    = number
    }))
}
```



The `SLOs` variable is a `map` of type `object` which will later allow you to declare a collection of objects to represent your SLOs as code. Each component of the SLO object is used to create the scheduled query alert. You can see how many of these components of the object map back to the example of the scheduled query alert rule resource. Other components are used to create naming conventions and to fully describe the SLO as code. 

In `sched_query_rules_alert.auto.tfvars` we supply values to the variables declared in `variables.tf`. These will be picked up automatically by the Terraform commands in the main deployment file because we supplied the extension `.auto.tfvars`. 

```
# sched_query_rules_alert.auto.tfvars
logAnalyticsResourceID="" #Your Log Analytics Resource ID
logAnalyticsResourceGroupName="" #Resource Group Name where you've created your Log Analytics Resource 
resourceRegion="eastus2"

# SLOs as Code Example 
SLOs = {
    "View Catalog-SuccessRate" = {
        userJourneyCategory = "View Catalog",
        sloCategory         = "SuccessRate",
        sloPercentile       = ""
        sloDescription      = "99.9% of \"/catalog\" request in the last 60 mins were successful (HTTP Response Code: 200) as measured at API Gateway",
        signalQuery         = <<-EOT
            AppRequests
                | where Url !contains "localhost" and Url !contains "/hc"
                | extend httpMethod = tostring(split(Name, ' ')[0])
                | where Name contains "Catalog"
                | summarize succeed = count(Success == true), failed = count(Success == false), total=count() by bin(TimeGenerated, 60m)
                | extend AggregatedValue = todouble(succeed) * 10000 / todouble(total)
        EOT
        signalSeverity      = 4,
        frequency           = 60,
        time_window         = 60,
        triggerOperator     = "LessThan",
        triggerThreshold    = 9990
    },

    "Login-SuccessRate" = {
        userJourneyCategory = "Login",
        sloCategory         = "SuccessRate",
        sloPercentile       = ""
        sloDescription      = "99.9% of \"login\" request in the last 60 mins were successful (HTTP Response Code: 200) as measured at API Gateway ",
        signalQuery         = <<-EOT
            AppRequests
                | where Url !contains "localhost" and Url !contains "/hc"
                | extend httpMethod = tostring(split(Name, ' ')[0])
                | where Name contains "login"
                | summarize succeed = count(Success == true), failed = count(Success == false), total=count() by bin(TimeGenerated, 60m)
                | extend AggregatedValue = todouble(succeed) * 10000 / todouble(total)
        EOT
        signalSeverity      = 4,
        frequency           = 60,
        time_window         = 60,
        triggerOperator     = "LessThan",
        triggerThreshold    = 9990
    }
}
```

The values for `logAnalyticsResourceID` and `logAnalyticsResourceGroupName` are specific your resources in your Azure subscription. After your deploy a `Log Analytics workspace` to your Azure subscription, navigate to the resource and the `Overview` tab in the blade menu. In the top left select `JSON View` and it will let you copy the resource ID to your clipboard and supply it to this file.

Refer to the SLOs object, which is similar to a JSON Object, instead of using the `:` operator to represent key value pairings, in terraform we use the `=` operator to represent key value parings. We map each component declared in `variables.tf` to describe the respective SLOs. The queries are delimited using Heredoc syntax starting with `<<-EOT` and ending with `EOT` so we do not need to escape characters within our query. 

This collection of SLOs in the `SLOs` variable will become our SLOs as code and gives us a maintainable way to deploy SLOs. 

Lastly in `main.tf` we take the orchestration of the variable files and finally implement them for deployment.

```
# main.tf

# Configure the Azure provider
terraform {
    required_providers {
        azurerm = {
                source = "hashicorp/azurerm"
                version = ">= 2.26"
        }
    }
}

provider "azurerm" {
    features {}
}

#Deploy a sample log query alert
resource "azurerm_monitor_scheduled_query_rules_alert" "SLO_ALERT" {
    for_each            = var.SLOs
    name                = format("%s-%s%s", each.value["userJourneyCategory"], each.value["sloCategory"], 
                            each.value["sloPercentile"])
    location            = var.resourceRegion
    resource_group_name = var.logAnalyticsResourceGroupName

    action {
        action_group           = var.alertActionGroups
        email_subject          = format("Alert - SLO Breach: %s-%s%s", each.value["userJourneyCategory"], 
                                    each.value["sloCategory"], each.value["sloPercentile"])
        custom_webhook_payload = var.webHookPayLoad
    }

    data_source_id = var.logAnalyticsResourceID
    description    = each.value["sloDescription"]
    enabled        = true
    query          = <<-QUERY
        ${each.value["signalQuery"]}
    QUERY
    
    severity    = each.value["signalSeverity"]
    frequency   = each.value["frequency"]
    time_window = each.value["time_window"]
    
    trigger {
        operator  = each.value["triggerOperator"]
        threshold = each.value["triggerThreshold"]
    }
}
```



The first line in the resource declaration is `for_each = var.SLOs` which accesses the `SLOs` variable declared in `sched_query_rules_alert.auto.tfvars`. This will iterate over each object declared in the `SLOs` variable. Since we declared 2 SLO objects in the `SLOs` variables, 2 resources will be deployed. Each component of the SLO objects can be accessed respectively via `each.value["<variable name>"]`. Normal variables are accessed via `var.<variable name>`. This iteration over the objects contained in the variable lets us deploy many alerts for SLOs in one deployment and can be utilized in our CI/CD pipelines. 

Using the basic terraform command syntax we can apply these pieces. Move into the working directory:

```powershell
cd scheduled_query_alert
```



Then initialize terraform in the folder:

```powershell
terraform init
```



Stage changes to the architecture:

```powershell
terraform plan
```



Lastly, apply the changes to your Azure Subscription:

```powershell
terraform apply
```



---

Advanced Scenario: Deploying Alerts via GitHub Actions

Prerequisites:

- All prerequisites outlined in Basic Scenario

- Understanding the Automated alert deployment lab and how terraform interacts with variable files

- GitHub Account

- Fork of the code 

  

> **_NOTE:_**  Terraform decides which infrastructure to change/create/or destroy based on the context of a `terraform.tfstate` file which is created locally when utilizing terraform commands. If you have done the previous scenario locally you should remove the previously created alerts in your Azure Subscription as we will now be using a cloud hosted `terraform.tfstate` file. 

#### Step 1: Terraform

Working Directory:

`/eShop-alerts-as-code/scheduled_query_alert_automated_deploy/`

Since we now have maintainable SLOs as Code, it only makes sense to automate the deployment end to end, so that when we make modifications, our alerts are changed and deployed. 

Our first step will be to create a resource group, if you already haven't.

```powershell
az group create -g <resource-group-name> -l <region>
```

For our purposes we will use the region `eastus2` and our resource group will be `sched_query_alert`. Feel free to adjust these to your own preferences. 

If you're comfortable in the portal we need to create a `storage account` in that resource group and a `storage container` in our respective storage account. We can also accomplish this with the AZ CLI. The reason we are doing this is so we have a persistent `.terraform.tfstate` to reference from our GitHub action's environment. 

Storage Account:

```powershell
az storage account create -n schedqueryalertsa  -g sched_query_alert -l eastus2 --sku Standard_LRS
```



Storage Container:

```powershell
az storage container create -n terraform-state --account-name schedqueryalertsa
```

 

Now that we have some underlying infrastructure prepared we can setup our `main.tf` file to point to our backend. 

```
# main.tf

# Configure the Azure provider
terraform {
    backend "azurerm" {
        resource_group_name  = "sched_query_alert" #Your resource group name
        storage_account_name = "schedqueryalertsa" #Your storage account name
        container_name       = "terraform-state" #Your container name
        key                  = "terraform.tfstate"
    }
}

provider "azurerm" {
    version = ">= 2.26"
    features {}
}

#Deploy a sample log query alert
resource "azurerm_monitor_scheduled_query_rules_alert" "SLO_ALERT" {
    for_each            = var.SLOs
    name                = format("%s-%s%s", each.value["userJourneyCategory"], each.value["sloCategory"], 
                            each.value["sloPercentile"])
    location            = var.resourceRegion
    resource_group_name = var.logAnalyticsResourceGroupName

    action {
        action_group           = var.alertActionGroups
        email_subject          = format("Alert - SLO Breach: %s-%s%s", each.value["userJourneyCategory"], 
                                    each.value["sloCategory"], each.value["sloPercentile"])
        custom_webhook_payload = var.webHookPayLoad
    }

    data_source_id = var.logAnalyticsResourceID
    description    = each.value["sloDescription"]
    enabled        = true
    query          = <<-QUERY
        ${each.value["signalQuery"]}
    QUERY
    
    severity    = each.value["signalSeverity"]
    frequency   = each.value["frequency"]
    time_window = each.value["time_window"]
    
    trigger {
        operator  = each.value["triggerOperator"]
        threshold = each.value["triggerThreshold"]
    }
}
```



The `terraform` block points to the resources we created in the previous steps, only for the purpose of utilizing the `terraform.tfsate` file. We will still need to supply other parameters in our variable files.

In `variables.tf` we will have the same structures declared, that will parametrize what we will pass into our `main.tf` file and declare in our `*.auto.tfvars` file. 

```
# variables.tf

variable "logAnalyticsResourceID" {
    type        = string
    description = "Resource ID of the Log Analytics workspace."
}

variable "logAnalyticsResourceGroupName"{
    type        = string
    description = "Name of Resource Group containing Log Analytics workspace"
}

variable "resourceRegion" {
    type        = string
    default     = "eastus2"
    description = "Location for the resource(s)."
}

variable "alertActionGroups" {
    type        = list(string)
    default     = []
    description = "Action group(s) for the alerts"
}

variable "webHookPayLoad" {
    type        = string
    default     = "{}"
    description = "Custom payload to be sent with the alert"
}

variable "SLOs" {
    type = map(object({
        userJourneyCategory = string, 
        sloCategory         = string,
        sloPercentile       = string,
        sloDescription      = string,
        signalQuery         = string,
        signalSeverity      = string,
        frequency           = number, 
        time_window         = number,
        triggerOperator     = string,
        triggerThreshold    = number
    }))
}
```



Lastly we modified `sched_query_rules_alert.auto.tfvars` to not include `logAnalyticsResourceID` or `logAnalyticsResourceGroupName`. We will supply these via secrets or command line arguments in our GitHub Actions files. 

```
# sched_query_rules_alert.auto.tfvars

resourceRegion="eastus2"

# SLOs as Code Example 
SLOs = {
    "View Catalog-SuccessRate" = {
        userJourneyCategory = "View Catalog",
        sloCategory         = "SuccessRate",
        sloPercentile       = ""
        sloDescription      = "99.9% of \"/catalog\" request in the last 60 mins were successful (HTTP Response Code: 200) as measured at API Gateway",
        signalQuery         = <<-EOT
            AppRequests
                | where Url !contains "localhost" and Url !contains "/hc"
                | extend httpMethod = tostring(split(Name, ' ')[0])
                | where Name contains "Catalog"
                | summarize succeed = count(Success == true), failed = count(Success == false), total=count() by bin(TimeGenerated, 60m)
                | extend AggregatedValue = todouble(succeed) * 10000 / todouble(total)
        EOT
        signalSeverity      = 4,
        frequency           = 60,
        time_window         = 60,
        triggerOperator     = "LessThan",
        triggerThreshold    = 9990
    },

    "Login-SuccessRate" = {
        userJourneyCategory = "Login",
        sloCategory         = "SuccessRate",
        sloPercentile       = ""
        sloDescription      = "99.9% of \"login\" request in the last 60 mins were successful (HTTP Response Code: 200) as measured at API Gateway ",
        signalQuery         = <<-EOT
            AppRequests
                | where Url !contains "localhost" and Url !contains "/hc"
                | extend httpMethod = tostring(split(Name, ' ')[0])
                | where Name contains "login"
                | summarize succeed = count(Success == true), failed = count(Success == false), total=count() by bin(TimeGenerated, 60m)
                | extend AggregatedValue = todouble(succeed) * 10000 / todouble(total)
        EOT
        signalSeverity      = 4,
        frequency           = 60,
        time_window         = 60,
        triggerOperator     = "LessThan",
        triggerThreshold    = 9990
    }
}
```



#### Step 2: GitHub Actions

Working Directory: 

`/.github/workflows/`



Assuming you have forked the code. Navigate to GitHub and your forked repository. Navigate to actions for eShop-alerts-as-code and enable actions. 
To allow any of these to run we need to supply our repository with secrets that our workflow can read. 

The first step is to create a service principle via the Azure CLI that's logged into your subscription. 

```powershell
az ad sp create-for-rbac --name "tf-deploy-eshop" --role Contributor --sdk-auth
```



The `--name` field is a name for your service principle. The output of this command should be:

```json
insert this here...
```



Save the output of this somewhere or have it readily available. In your forked repository navigate to `Settings` and the `Secrets` on the left hand side of the screen.

On the `Actions secrets` screen click `New repository secret`. 

In the `Name` field supply `TF_ARM_CLIENT_ID` and in the `Value` field supply the value from the  service principle output for `ClientId` <--- double check this. 

Repeat the process for the following authentication secrets:

`TF_ARM_CLIENT_ID` (if not already done). 

`TF_ARM_CLIENT_SECRET`

`TF_ARM_SUBSCRIPTION_ID`

`TF_ARM_TENANT_ID` 

For the last secret, we will supply the Log Analytics Resource ID as we do not want to commit this to version control. 

The name for this secret is `VAR_LA_RESOURCE_ID` and the value can be supplied in the form of: 

`"logAnalyticsResourceID=<Your Log Analytics Resource ID>"` double quotes included. This maps directly to our `variables.tf` file. 

```
# variables.tf 

variable "logAnalyticsResourceID" {
    type        = string
    description = "Resource ID of the Log Analytics workspace."
}
```

And we will reference these variables and secrets directly in the terraform commands. 

`/eShop-alerts-as-code/.github/workflows/`

There are 3 workflows for GitHub actions. 

1. A manual end to end deployment
2. On a pull request, verify and stage changes 

3. On a merge (or commit to main), verify and stage changes, then apply them. 



Workflow 1: Manual End to End Deployment  

```yaml
# manual-terraform-deploy.yml

name: manual terraform deploy

on:

  workflow_dispatch:
    # Inputs the workflow accepts.
    inputs:
      name:
        # Friendly description to be shown in the UI instead of 'name'
        description: 'execution name'
        # Default value if no value is explicitly provided
        default: 'Manual End to End Deployment'
        # Input has to be provided for the workflow to run
        required: false


defaults:
  run:
    working-directory:
      scheduled_query_alert_automated_deploy

jobs:
  terraform:
    runs-on: ubuntu-latest

    env:
      ARM_CLIENT_ID: ${{secrets.TF_ARM_CLIENT_ID}}
      ARM_CLIENT_SECRET: ${{secrets.TF_ARM_CLIENT_SECRET}}
      ARM_SUBSCRIPTION_ID: ${{secrets.TF_ARM_SUBSCRIPTION_ID}}
      ARM_TENANT_ID: ${{secrets.TF_ARM_TENANT_ID}}

    steps:
      - uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan -var="logAnalyticsResourceGroupName=eShop-Alert-Automation" -var=${{ secrets.VAR_LA_RESOURCE_ID }}

      - name: Terraform Apply
        run: terraform apply -var="logAnalyticsResourceGroupName=eShop-Alert-Automation" -var=${{ secrets.VAR_LA_RESOURCE_ID }} -auto-approve
```



The `on` block in the YAML contains a `workflow-dispatch` trigger. This allows us to manually run the action from our repository site. 

Under `defaults` we set the working directory to `scheduled_query_alert_automated_deploy` to utilize the terraform files set up to talk to our backend `terraform.tfstate` file and utilize our secrets in the command line. 

Under `jobs` we name our job `terraform` and setup our `env` with variables corresponding to our service principal secrets. Terraform will automatically pick up on these environment variables and authenticate to Azure. 

Lastly in `steps` we walk through a normal terraform flow:

- Initialize the terraform project
- Then plan and supply appropriate variables via
- Then apply the plan with the same variables. The `-auto-approve` flag will allow this to run without extra user input. 

If you have set this up correctly you should be able to go to your repository, select the workflow `manual terraform deploy` and select `run workflow`. The action should deploy your alerts end to end. 



Workflow 2: Pull Request 

 ``` YAML
name: pull request validation

on:
  pull_request:
    branches: [ master ]


defaults:
  run:
    working-directory:
      scheduled_query_alert_automated_deploy

jobs:
  terraform:
    runs-on: ubuntu-latest

    env:
      ARM_CLIENT_ID: ${{secrets.TF_ARM_CLIENT_ID}}
      ARM_CLIENT_SECRET: ${{secrets.TF_ARM_CLIENT_SECRET}}
      ARM_SUBSCRIPTION_ID: ${{secrets.TF_ARM_SUBSCRIPTION_ID}}
      ARM_TENANT_ID: ${{secrets.TF_ARM_TENANT_ID}}

    steps:
      - uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan -var="logAnalyticsResourceGroupName=eShop-Alert-Automation" -var=${{ secrets.VAR_LA_RESOURCE_ID }}
 ```

The changes made here are in the `on` block and specifies to run the jobs on a pull request to master. The steps actions only handles an initialize and a plan which will both verify any changes made to the code as well as stage the changes to be applied. 



Workflow 3: Push to main (merge pull request)

```Yaml
name: apply on push

on:
  push:
    branches: [ master ]

defaults:
  run:
    working-directory:
      scheduled_query_alert_automated_deploy

jobs:
  terraform:
    runs-on: ubuntu-latest

    env:
      ARM_CLIENT_ID: ${{secrets.TF_ARM_CLIENT_ID}}
      ARM_CLIENT_SECRET: ${{secrets.TF_ARM_CLIENT_SECRET}}
      ARM_SUBSCRIPTION_ID: ${{secrets.TF_ARM_SUBSCRIPTION_ID}}
      ARM_TENANT_ID: ${{secrets.TF_ARM_TENANT_ID}}

    steps:
      - uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Apply
        run: terraform apply -var="logAnalyticsResourceGroupName=eShop-Alert-Automation" -var=${{ secrets.VAR_LA_RESOURCE_ID }} -auto-approve
```

The changes made here are in the `on` block and specifies to run the job on a push to master. Ideally this would happen after a pull request validation and it would apply the staged changes in the `terraform apply` step in the previous workflow. 



This concludes the basics of deploying automatic alerts via GitHub actions. With an extended knowledge of terraform you can customize these actions and apply the logic to deploying other pieces of infrastructure in terraform. 



















