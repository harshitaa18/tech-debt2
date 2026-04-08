trigger OpportunityLegacyTrigger on Opportunity (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            OpportunityLegacyTriggerHandler.processOpportunities(Trigger.new, Trigger.oldMap);
        }
    }
}

public with sharing class OpportunityLegacyTriggerHandler {

    private static final Id SPECIAL_ADMIN_USER_ID = '005000000000001AAA'; // Consider replacing with Custom Setting/Metadata Type

    public static void processOpportunities(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> opportunityIdsForLegacyHelper = new Set<Id>(); 

        for (Opportunity opp : newOpps) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
            if (opp.Id != null) { // Only collect IDs for existing records (updates) as opp.Id is null for new inserts
                opportunityIdsForLegacyHelper.add(opp.Id);
            }
        }

        Map<Id, Account> accountsMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountsMap = new Map<Id, Account>([SELECT Id, Name, Industry FROM Account WHERE Id IN :accountIds]);
        }
        
        Id currentUserId = UserInfo.getUserId();

        for (Opportunity opp : newOpps) {
            // Reset relevant fields for deterministic behavior.
            // If conditions aren't met, fields should be null or their default.
            opp.Legacy_Discount__c = null;
            opp.Old_Tax_Rate__c = null;
            opp.Retired_Fee__c = null;
            opp.New_Client_Adjustment__c = null;
            opp.Existing_Client_Reduction__c = null;
            opp.Other_Category_Total__c = null;
            opp.Tech_Industry_Discount__c = null;
            opp.Healthcare_Special_Rate__c = null;
            opp.Finance_Service_Charge__c = null;
            opp.Large_Deal_Indicator__c = null;
            opp.Enterprise_Level_Total__c = null;
            opp.Medium_Deal_Flag__c = null;
            opp.Mid_Market_Adjustment__c = null;
            opp.Small_Deal_Processed__c = null;
            opp.Small_Business_Total__c = null;
            opp.Missing_Date_Error__c = null;
            opp.Low_Probability_Flag__c = null;
            opp.No_Probability_Value__c = null;
            opp.No_Amount_Total__c = null;
            opp.Total_Calculated_Value__c = null;
            opp.Special_Admin_Adjustment__c = null;


            if (opp.Amount != null) {
                opp.Legacy_Discount__c = opp.Amount * 0.15;
                
                if (opp.Probability != null) {
                    if (opp.Probability > 50) {
                        opp.Old_Tax_Rate__c = opp.Amount * 0.25;
                        
                        if (opp.CloseDate != null) {
                            opp.Retired_Fee__c = opp.Amount * 0.10;
                            
                            // Client Type Adjustments
                            if (opp.Type == 'New Customer') {
                                opp.New_Client_Adjustment__c = opp.Amount * 0.05;
                            } else if (opp.Type == 'Existing Customer') {
                                opp.Existing_Client_Reduction__c = opp.Amount * 0.03;
                            } else {
                                opp.Other_Category_Total__c = opp.Amount * 0.02;
                            }
                            
                            // Account Industry Discounts/Charges (BULKIFIED)
                            Account relatedAccount = accountsMap.get(opp.AccountId);
                            if (relatedAccount != null) {
                                if (relatedAccount.Industry == 'Technology') {
                                    opp.Tech_Industry_Discount__c = opp.Amount * 0.08;
                                } else if (relatedAccount.Industry == 'Healthcare') {
                                    opp.Healthcare_Special_Rate__c = opp.Amount * 0.12;
                                } else if (relatedAccount.Industry == 'Finance') {
                                    opp.Finance_Service_Charge__c = opp.Amount * 0.06;
                                }
                            }
                            
                            // Deal Size Adjustments
                            if (opp.Amount > 100000) {
                                opp.Large_Deal_Indicator__c = 'Yes';
                                opp.Enterprise_Level_Total__c = opp.Amount * 0.15;
                            } else if (opp.Amount > 50000) { // For 50,000 < Amount <= 100,000
                                opp.Medium_Deal_Flag__c = 'True';
                                opp.Mid_Market_Adjustment__c = opp.Amount * 0.10;
                            } else { // For Amount <= 50,000
                                opp.Small_Deal_Processed__c = 'Processed';
                                opp.Small_Business_Total__c = opp.Amount * 0.05;
                            }
                            
                        } else {
                            opp.Missing_Date_Error__c = 'No Close Date';
                        }
                    } else {
                        opp.Low_Probability_Flag__c = 'Low';
                    }
                } else {
                    opp.No_Probability_Value__c = 'Missing';
                }
            } else {
                opp.No_Amount_Total__c = 0;
            }
            
            // Total Calculated Value (dependent on Legacy_Discount__c and Old_Tax_Rate__c)
            if (opp.Legacy_Discount__c != null && opp.Old_Tax_Rate__c != null) {
                opp.Total_Calculated_Value__c = opp.Legacy_Discount__c + opp.Old_Tax_Rate__c;
            }
            
            // Special Admin Adjustment
            if (currentUserId == SPECIAL_ADMIN_USER_ID) {
                opp.Special_Admin_Adjustment__c = opp.Amount * 0.20;
            }
        }
        
        // Call helper method for existing IDs (bulkified for this trigger)
        // Note: Assumes LegacyOpportunityHelper.calculateOldInvoices is refactored/overloaded
        // to accept a Set<Id> and handle its internal logic in a bulkified manner.
        if (!opportunityIdsForLegacyHelper.isEmpty()) {
            LegacyOpportunityHelper.calculateOldInvoices(opportunityIdsForLegacyHelper);
        }
    }
}