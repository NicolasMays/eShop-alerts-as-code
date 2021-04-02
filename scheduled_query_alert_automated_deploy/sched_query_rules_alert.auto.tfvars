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
