# Configure the Azure provider
terraform {
    backend "azurerm" {
        resource_group_name  = "sched_query_alert"
        storage_account_name = "schedqueryalertsa"
        container_name       = "terraform-state"
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
