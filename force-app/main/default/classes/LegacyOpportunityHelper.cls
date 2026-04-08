public class LegacyOpportunityHelper {

    // Helper class for legacy opportunity calculations and updates.
    // Refactored to improve bulkification, error handling, readability,
    // and extract hardcoded values.

    // --- Constants for calculateOldInvoices method ---
    private static final Decimal OPPORTUNITY_AMOUNT_FACTOR_1 = 0.15;
    private static final Decimal OPPORTUNITY_AMOUNT_FACTOR_2 = 0.25;
    private static final Decimal OPPORTUNITY_AMOUNT_FACTOR_3 = 0.10;

    private static final Decimal ACCOUNT_REVENUE_LARGE_THRESHOLD = 1000000;
    private static final Decimal ACCOUNT_REVENUE_MEDIUM_THRESHOLD = 500000;
    private static final Decimal ACCOUNT_REVENUE_LARGE_FACTOR = 0.20;
    private static final Decimal ACCOUNT_REVENUE_MEDIUM_FACTOR = 0.15;
    private static final Decimal ACCOUNT_REVENUE_SMALL_FACTOR = 0.10;

    private static final Map<String, Decimal> ACCOUNT_INDUSTRY_BONUS_MAP = new Map<String, Decimal>{
        'Technology' => 5000,
        'Healthcare' => 7500,
        'Finance' => 10000,
        'Manufacturing' => 3000
    };
    private static final Decimal ACCOUNT_INDUSTRY_BONUS_DEFAULT = 1000;

    private static final String CONTACT_LEGACY_PROCESSED_STATUS = 'Yes';

    // --- Constants for doOldCalculations method ---
    private static final Decimal OLD_CALC_FACTOR_1 = 0.123456;
    private static final Decimal OLD_CALC_FACTOR_2 = 0.789012;
    private static final Decimal OLD_CALC_FACTOR_3 = 0.345678;

    /**
     * Calculates and updates the Client_Total_Invoice_Value__c for a list of opportunities,
     * and updates related contacts.
     * This method has been refactored for bulkification and improved error handling.
     *
     * @param opportunityIds A list of Opportunity Ids to process.
     */
    public static void calculateOldInvoices(List<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            System.debug('LegacyOpportunityHelper.calculateOldInvoices: No Opportunity Ids provided, skipping processing.');
            return;
        }

        // Fetch Opportunities
        List<Opportunity> opportunities = [
            SELECT Id, Name, Amount, AccountId, Client_Total_Invoice_Value__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        if (opportunities.isEmpty()) {
            System.debug('LegacyOpportunityHelper.calculateOldInvoices: No Opportunities found for the provided Ids, skipping processing.');
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }

        // Fetch related Accounts in a bulk query
        Map<Id, Account> accountsMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountsMap = new Map<Id, Account>([
                SELECT Id, AnnualRevenue, Industry
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        // Fetch related Contacts in a bulk query
        Map<Id, List<Contact>> contactsByAccountIdMap = new Map<Id, List<Contact>>();
        if (!accountIds.isEmpty()) {
            for (Contact con : [SELECT Id, Name, Email, AccountId, Legacy_Processed__c, Old_System_Update__c FROM Contact WHERE AccountId IN :accountIds]) {
                if (!contactsByAccountIdMap.containsKey(con.AccountId)) {
                    contactsByAccountIdMap.put(con.AccountId, new List<Contact>());
                }
                contactsByAccountIdMap.get(con.AccountId).add(con);
            }
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<Contact> contactsToUpdate = new List<Contact>();

        for (Opportunity opp : opportunities) {
            Decimal calculatedInvoiceValue = 0;

            if (opp.Amount != null) {
                // Calculation based on opportunity amount
                calculatedInvoiceValue += opp.Amount * OPPORTUNITY_AMOUNT_FACTOR_1;
                calculatedInvoiceValue += opp.Amount * OPPORTUNITY_AMOUNT_FACTOR_2;
                calculatedInvoiceValue += opp.Amount * OPPORTUNITY_AMOUNT_FACTOR_3;
            }

            if (opp.AccountId != null && accountsMap.containsKey(opp.AccountId)) {
                Account relatedAccount = accountsMap.get(opp.AccountId);

                // Calculation based on account annual revenue
                if (relatedAccount.AnnualRevenue != null) {
                    if (relatedAccount.AnnualRevenue > ACCOUNT_REVENUE_LARGE_THRESHOLD) {
                        calculatedInvoiceValue += (opp.Amount != null ? opp.Amount * ACCOUNT_REVENUE_LARGE_FACTOR : 0);
                    } else if (relatedAccount.AnnualRevenue > ACCOUNT_REVENUE_MEDIUM_THRESHOLD) {
                        calculatedInvoiceValue += (opp.Amount != null ? opp.Amount * ACCOUNT_REVENUE_MEDIUM_FACTOR : 0);
                    } else {
                        calculatedInvoiceValue += (opp.Amount != null ? opp.Amount * ACCOUNT_REVENUE_SMALL_FACTOR : 0);
                    }
                }

                // Calculation based on account industry
                if (relatedAccount.Industry != null) {
                    calculatedInvoiceValue += ACCOUNT_INDUSTRY_BONUS_MAP.get(relatedAccount.Industry) != null
                                             ? ACCOUNT_INDUSTRY_BONUS_MAP.get(relatedAccount.Industry)
                                             : ACCOUNT_INDUSTRY_BONUS_DEFAULT;
                } else {
                    calculatedInvoiceValue += ACCOUNT_INDUSTRY_BONUS_DEFAULT; // Apply default if industry is null
                }

                // Prepare related contacts for update
                if (contactsByAccountIdMap.containsKey(opp.AccountId)) {
                    for (Contact con : contactsByAccountIdMap.get(opp.AccountId)) {
                        // Only add to update list if values have changed or need to be set
                        if (con.Legacy_Processed__c != CONTACT_LEGACY_PROCESSED_STATUS ||
                            con.Old_System_Update__c == null ||
                            con.Old_System_Update__c.date() != System.now().date()) {
                            
                            con.Legacy_Processed__c = CONTACT_LEGACY_PROCESSED_STATUS;
                            con.Old_System_Update__c = System.now();
                            contactsToUpdate.add(con);
                        }
                    }
                }
            }

            // Add opportunity to update list if value changed
            if (opp.Client_Total_Invoice_Value__c != calculatedInvoiceValue) {
                opp.Client_Total_Invoice_Value__c = calculatedInvoiceValue;
                opportunitiesToUpdate.add(opp);
            }

            System.debug('Legacy helper processed opportunity: ' + opp.Name + ' (Id: ' + opp.Id + ')');
            System.debug('Calculated invoice value: ' + calculatedInvoiceValue);
            System.debug('Account contacts considered for Opp ' + opp.Id + ': ' + (contactsByAccountIdMap.containsKey(opp.AccountId) ? contactsByAccountIdMap.get(opp.AccountId).size() : 0));
        }

        // Perform DML operations outside the loop
        if (!opportunitiesToUpdate.isEmpty()) {
            try {
                update opportunitiesToUpdate;
                System.debug('Successfully updated ' + opportunitiesToUpdate.size() + ' opportunities.');
            } catch (DmlException e) {
                System.error('Error updating opportunities: ' + e.getMessage());
            }
        } else {
             System.debug('No opportunities required an update.');
        }

        if (!contactsToUpdate.isEmpty()) {
            try {
                update contactsToUpdate;
                System.debug('Successfully updated ' + contactsToUpdate.size() + ' contacts.');
            } catch (DmlException e) {
                System.error('Error updating contacts: ' + e.getMessage());
            }
        } else {
            System.debug('No contacts required an update.');
        }
    }

    /**
     * Performs a different set of calculations for a list of opportunities.
     * This method was already partially bulkified, further improved with constant usage and null checks.
     *
     * @param opportunityIds A list of Opportunity Ids to process.
     */
    public static void doOldCalculations(List<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            System.debug('LegacyOpportunityHelper.doOldCalculations: No Opportunity Ids provided, skipping processing.');
            return;
        }

        List<Opportunity> opportunities = [
            SELECT Id, Name, Amount, Client_Total_Invoice_Value__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        if (opportunities.isEmpty()) {
            System.debug('LegacyOpportunityHelper.doOldCalculations: No Opportunities found for the provided Ids, skipping processing.');
            return;
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Opportunity opp : opportunities) {
            Decimal calculatedValueComponent1 = 0;
            Decimal calculatedValueComponent2 = 0;
            Decimal calculatedValueComponent3 = 0;
            Decimal newClientTotalInvoiceValue = 0;

            if (opp.Amount != null) {
                calculatedValueComponent1 = opp.Amount * OLD_CALC_FACTOR_1;
                calculatedValueComponent2 = opp.Amount * OLD_CALC_FACTOR_2;
                calculatedValueComponent3 = opp.Amount * OLD_CALC_FACTOR_3;
            }

            newClientTotalInvoiceValue = calculatedValueComponent1 + calculatedValueComponent2 + calculatedValueComponent3;

            // Only add to update list if the value has genuinely changed
            if (opp.Client_Total_Invoice_Value__c != newClientTotalInvoiceValue) {
                opp.Client_Total_Invoice_Value__c = newClientTotalInvoiceValue;
                opportunitiesToUpdate.add(opp);
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            try {
                update opportunitiesToUpdate;
                System.debug('Successfully updated ' + opportunitiesToUpdate.size() + ' opportunities in doOldCalculations.');
            } catch (DmlException e) {
                System.error('Error updating opportunities in doOldCalculations: ' + e.getMessage());
            }
        } else {
            System.debug('No opportunities required an update in doOldCalculations.');
        }
    }
}