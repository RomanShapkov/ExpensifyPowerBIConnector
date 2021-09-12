// This file contains your Data Connector logic
section ExpensifyPowerBIConnector;


ServerURl = "https://integrations.expensify.com/Integration-Server/ExpensifyIntegrations";

partnerUserID = Text.BeforeDelimiter(Extension.CurrentCredential()[Key], ":");
partnerUserSecret = Text.AfterDelimiter(Extension.CurrentCredential()[Key], ":");


templateReports = "[<#list reports as report>
        {<#t>
            ""reportID"": ""${report.reportID}"",
            ""reportName"": ""${report.reportName}"",
            ""totalCurrency"": ""${report.currency}"",
            ""total"": ""${report.total}"",
            ""totalAmount"": ""${report.total/100}"",
            ""status"": ""${report.status}"",
            ""accountEmail"": ""${report.accountEmail}"",
            ""accountID"": ""${report.accountID}"",
            ""approved"": ""${report.approved}"",
            ""approvers"": ""${report.approvers}"",
            ""created"": ""${report.created}"",
            ""isACHReimbursed"": ""${report.isACHReimbursed}"",
            ""managerEmail"": ""${report.managerEmail}"",
            ""managerUserID"": ""${report.managerUserID}"",
            ""managerPayrollID"": ""${report.managerPayrollID}"",
            ""managerFirstName"": ""${report.manager.firstName}"",
            ""managerLastName"": ""${report.manager.lastName}"",
            ""managerFullName"": ""${report.manager.fullName}"",
            ""policyName"": ""${report.policyName}"",
            ""policyID"": ""${report.policyID}"",
            ""reimbursed"": ""${report.reimbursed}"",
            ""submitted"": ""${report.submitted}"",
            ""employeeCustomField1"": ""${report.employeeCustomField1}"",
            ""employeeCustomField2"": ""${report.employeeCustomField2}"",
            ""submitterFirstName"": ""${report.submitter.firstName}"",
            ""submitterLastName"": ""${report.submitter.lastName}"",
            ""submitterFullName"": ""${report.submitter.fullName}""
        }<#sep>,</#sep>
</#list>]";

templateExpense = "
[<#list reports as report>
    [<#list report.transactionList as expense>
      {
        ""transactionID"": ""${expense.transactionID}"",
        ""reportID"": ""${expense.reportID}"",
        ""tag"": ""${report.tag}"",
        ""comment"": ""${expense.comment}"",
                        
        <#if expense.modifiedCreated?has_content>
                ""assignCreated"": ""${expense.modifiedCreated}""
        <#else> ""assignCreated"": ""${expense.created}""
        </#if>,
                        
        ""created"":  ""${expense.created}"",
        ""modifiedCreated"": ""${expense.modifiedCreated}"",
        
        <#if expense.modifiedMerchant?has_content>
               ""assignMerchant"": ""${expense.modifiedMerchant}""
        <#else> ""assignMerchant"": ""${expense.merchant}""</#if>,
            
        ""merchant"": ""${expense.merchant}"",
        ""modifiedMerchant"": ""${expense.modifiedMerchant}"",
        ""currency"":  ""${expense.currency}"",
                         
        <#if expense.convertedAmount?has_content>
             ""assignAmount"":  ""${expense.convertedAmount/100}""
        <#elseif expense.modifiedAmount?has_content>
              ""assignAmount"":  ""${expense.modifiedAmount/100}""
        <#else>
              ""assignAmount"": ""${expense.amount/100}""
        </#if>,
                          
        ""amount"": ""${expense.amount}"",
        ""modifiedAmount"": ""${expense.modifiedAmount}"",
        ""modifiedMCC"": ""${expense.modifiedMCC}"",
        ""hasTax"": ""${expense.hasTax}"",
        ""taxAmount"": ""${expense.taxAmount}"",
        ""taxName"": ""${expense.taxName}"",
        ""convertedAmount"": ""${expense.convertedAmount}"",
        ""currencyConversionRate"": ""${expense.currencyConversionRate}"", 
        ""billable"": ""${expense.billable?string(""true"", ""false"")}"", 
        ""category"": ""${expense.category}"",
        ""categoryGlCode"": ""${expense.categoryGlCode}"",
        ""categoryPayrollCode"": ""${expense.categoryPayrollCode}"",
        ""inserted"": ""${expense.inserted}"",
        ""mcc"": ""${expense.mcc}"",
        ""type"": ""${expense.type}"",
        ""unitsCount"": ""${expense.units.count}"",
        ""unitsRate"": ""${expense.units.rate}"",
        ""unitsUnit"": ""${expense.units.unit}""
       }<#sep>,</#sep>
    </#list>]<#sep>,</#sep>
</#list>]
";

[DataSource.Kind="ExpensifyPowerBIConnector", Publish="ExpensifyPowerBIConnector.Publish"]

shared Expensify.NavTableNested = (optional account as text) as table =>
    let

        NavTable = (tb as table) => Table.ToNavigationTable(tb, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        table_header = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},

        lv1 = #table(
            table_header,
            {
                {"fGetReports", "fGetReports", Expensify.Reports, "function", "function", "true"},
                {"fGetReportsExpense", "fGetReportsExpense", Expensify.ReportsExpense, "function", "function", "true"},
                {"fGetGetReportByTemplate", "fGetGetReportByTemplate", Expensify.GetReportByTemplate, "function", "function", "true"}
            }   
        )
    in
        NavTable(lv1);

Expensify.CreateReport = (startDate as date, endDate as date, template as text) =>
    let

        headers = [#"Content-Type" = "application/x-www-form-urlencoded"],
        report = [
            #"type" = "file",
            #"credentials" = [
                partnerUserID = partnerUserID, 
                partnerUserSecret = partnerUserSecret
                ],
            #"onReceive" = [
                immediateResponse = {"returnRandomFileName"}
                ],
            #"inputSettings" = [
                #"type" = "combinedReportData",
                #"filters" = [
                    #"startDate" = Date.ToText(startDate, "yyyy-MM-dd"), 
                    #"endDate" = Date.ToText(endDate, "yyyy-MM-dd")
                    ]
                ],
            #"outputSettings" = [
                #"fileExtension" = "json", 
                #"fileBasename" = "myExport"
                ]
        ],
        params = [
            requestJobDescription = Text.FromBinary(Json.FromValue(report)),
            template = template
        ],
        reportname = Text.FromBinary(Web.Contents( ServerURl, [Query = params]))
    in
        reportname;

Expensify.GetReportByTemplateImpl = (startDate as date, endDate as date, template as text) =>
    let
        reportname = Expensify.CreateReport(startDate, endDate, template),
        requests = [
            #"type" = "download",
            #"credentials" = [
                partnerUserID = partnerUserID, 
                partnerUserSecret = partnerUserSecret
                ],
            #"fileName" = reportname
        ],
        params = [requestJobDescription = Text.FromBinary(Json.FromValue(requests))],
        json = Json.Document(Web.Contents( ServerURl, [Query = params]))
    in
        json;


Expensify.ReportsImpl = (startDate as date, endDate as date) =>
    let
        data = Expensify.GetReportByTemplate(startDate, endDate, templateReports),
        table = toTable(data, 1)
    in
        table;

Expensify.ReportsExpenseImpl = (startDate as date, endDate as date) =>
    let
        lstData = Expensify.GetReportByTemplate(startDate, endDate, templateExpense),
        data = List.Combine(lstData),
        table = toTable(data, 1)
    in
        table;


// Data Source Kind description
ExpensifyPowerBIConnector = [
    TestConnection = (dataSourcePath) => {"Expensify.NavTableNested"},
    Authentication = [
        Key = [
            KeyLabel = "input {partnerUserID:partnerUserSecret}"
        ],
        //UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
ExpensifyPowerBIConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = ExpensifyPowerBIConnector.Icons,
    SourceTypeImage = ExpensifyPowerBIConnector.Icons
];

ExpensifyPowerBIConnector.Icons = [
    Icon16 = { Extension.Contents("ExpensifyPowerBIConnector16.png"), Extension.Contents("ExpensifyPowerBIConnector20.png"), Extension.Contents("ExpensifyPowerBIConnector24.png"), Extension.Contents("ExpensifyPowerBIConnector32.png") },
    Icon32 = { Extension.Contents("ExpensifyPowerBIConnector32.png"), Extension.Contents("ExpensifyPowerBIConnector40.png"), Extension.Contents("ExpensifyPowerBIConnector48.png"), Extension.Contents("ExpensifyPowerBIConnector64.png") }
];


Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;


toTable = (lstrec as list, optional index as number) as table =>
    let
        fieldnames = 
            let
                toprows = if index is null then lstrec else List.FirstN(lstrec, index),
                listfields = List.Transform(toprows, Record.FieldNames),
                namesdistinct = List.Union(listfields)
            in
                namesdistinct,
        tbl = Table.FromRecords(lstrec, fieldnames, MissingField.UseNull)
    in
        tbl;


Expensify.Reports = Value.ReplaceType(Expensify.ReportsImpl, Expensify.ReportsType);
Expensify.ReportsType =
type function (  
                     startDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created before the given date, whichever occurred last (inclusive)"
                        ]),
                     endDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created after the given date, whichever occurred last (inclusive)"
                        ])
                   )
        as function meta [
            Documentation.Name = "fGetReport",
            Documentation.LongDescription = "Get Expensify reports"
    ];


Expensify.GetReportByTemplate = Value.ReplaceType(Expensify.GetReportByTemplateImpl, Expensify.GetReportByTemplateType);
Expensify.GetReportByTemplateType =
type function (  
                     startDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created before the given date, whichever occurred last (inclusive)"
                        ]),
                     endDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created after the given date, whichever occurred last (inclusive)"
                        ]),
                     template as (type text meta [
                        Documentation.FieldCaption = "template",
                        Documentation.FieldDescription = "See the export template format reference for more information about how to write export templates.",
                        Documentation.SampleValues = {simpleTemplate},
                        Formatting.IsMultiLine = true,
                        Formatting.IsCode = true
                        ])
                    
                   )
        as function meta [
            Documentation.Name = "fGetReportByTemplate",
            Documentation.LongDescription = "Get Expensify custom report by template obj"
    ];


Expensify.ReportsExpense = Value.ReplaceType(Expensify.ReportsExpenseImpl, Expensify.ReportsExpenseType);
Expensify.ReportsExpenseType =
type function (  
                     startDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created before the given date, whichever occurred last (inclusive)"
                        ]),
                     endDate as (type date meta [
                        Documentation.FieldCaption = "dateStart",
                        Documentation.FieldDescription = "Filters out all reports submitted or created after the given date, whichever occurred last (inclusive)"
                        ])
                   )
        as function meta [
            Documentation.Name = "fGetReportsExpense",
            Documentation.LongDescription = "Get array of objects representing the expenses of the report"
    ];

simpleTemplate = "<#list reports as report>
    ${report.reportName},<#t>
    ${report.reportID},<#t>
    ${report.accountEmail}<#lt>
</#list>";