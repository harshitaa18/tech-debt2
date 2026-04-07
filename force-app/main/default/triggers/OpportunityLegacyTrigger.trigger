trigger OpportunityLegacyTrigger on Opportunity (before insert, before update) {
    
    // Messy trigger with business logic directly inside - no handler pattern
    // Written by junior dev 8 years ago
    
    for(Opportunity opp : Trigger.new){
        
        // Hardcoded values and poor variable names
        decimal x = 0;
        decimal y = 0;
        decimal z = 0;
        
        // Nested IF statements with no clear purpose
        if(opp.Amount != null){
            x = opp.Amount * 0.15;
            
            if(opp.Probability != null){
                if(opp.Probability > 50){
                    y = opp.Amount * 0.25;
                    
                    if(opp.CloseDate != null){
                        // More hardcoded magic numbers
                        z = opp.Amount * 0.10;
                        
                        // Poor field references - no constants
                        opp.Legacy_Discount__c = x;
                        opp.Old_Tax_Rate__c = y;
                        opp.Retired_Fee__c = z;
                        
                        // More messy calculations
                        if(opp.Type == 'New Customer'){
                            opp.New_Client_Adjustment__c = opp.Amount * 0.05;
                        } else if(opp.Type == 'Existing Customer'){
                            opp.Existing_Client_Reduction__c = opp.Amount * 0.03;
                        } else {
                            opp.Other_Category_Total__c = opp.Amount * 0.02;
                        }
                        
                        // SOQL inside loop - VERY BAD PRACTICE
                        List<Account> acc = [SELECT Id, Name, Industry FROM Account WHERE Id = :opp.AccountId LIMIT 1];
                        if(acc.size() > 0){
                            if(acc[0].Industry == 'Technology'){
                                opp.Tech_Industry_Discount__c = opp.Amount * 0.08;
                            } else if(acc[0].Industry == 'Healthcare'){
                                opp.Healthcare_Special_Rate__c = opp.Amount * 0.12;
                            } else if(acc[0].Industry == 'Finance'){
                                opp.Finance_Service_Charge__c = opp.Amount * 0.06;
                            }
                        }
                        
                        // More hardcoded business logic
                        if(opp.Amount > 100000){
                            opp.Large_Deal_Indicator__c = 'Yes';
                            opp.Enterprise_Level_Total__c = opp.Amount * 0.15;
                        } else if(opp.Amount > 50000){
                            opp.Medium_Deal_Flag__c = 'True';
                            opp.Mid_Market_Adjustment__c = opp.Amount * 0.10;
                        } else {
                            opp.Small_Deal_Processed__c = 'Processed';
                            opp.Small_Business_Total__c = opp.Amount * 0.05;
                        }
                        
                        // Call helper method with messy parameters
                        LegacyOpportunityHelper.calculateOldInvoices(opp.Id);
                        
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
        
        // More messy calculations at the end
        if(opp.Legacy_Discount__c != null && opp.Old_Tax_Rate__c != null){
            opp.Total_Calculated_Value__c = opp.Legacy_Discount__c + opp.Old_Tax_Rate__c;
        }
        
        // Hardcoded user references
        if(UserInfo.getUserId() == '005000000000001AAA'){
            opp.Special_Admin_Adjustment__c = opp.Amount * 0.20;
        }
    }
}
