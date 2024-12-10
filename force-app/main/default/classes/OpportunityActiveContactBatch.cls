public class OpportunityActiveContactBatch implements Database.Batchable<SObject>, Database.Stateful {
    // Variables to store data across batch execution
    private String lastActivityDateAPIName;
    private Integer nod;
    private Date SOQLDate;

    // Constructor to initialize variables
    public OpportunityActiveContactBatch(String lastActivityDateAPIName, Integer nod, Date SOQLDate) {
        this.lastActivityDateAPIName = lastActivityDateAPIName;
        this.nod = nod;
        this.SOQLDate = SOQLDate;
    }

    // Start method to query all closed Opportunities on or after the specified date
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all closed Opportunities with CloseDate on or after the input SOQLDate
        String query = 'SELECT Id, StageName, CreatedDate, CloseDate ' +
                       'FROM Opportunity ' +
                       'WHERE IsClosed = true AND CloseDate >= :SOQLDate';

        return Database.getQueryLocator(query);
    }

    // Execute method to process a batch of Opportunities
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        // Collect Opportunity IDs
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : scope) {
            oppIds.add(opp.Id);
        }

        // Get related Opportunity Contact Roles
        Map<Id, List<OpportunityContactRole>> oppToOCRs = new Map<Id, List<OpportunityContactRole>>();
        for (OpportunityContactRole ocr : [
            SELECT OpportunityId, ContactId 
            FROM OpportunityContactRole 
            WHERE OpportunityId IN :oppIds
        ]) {
            if (!oppToOCRs.containsKey(ocr.OpportunityId)) {
                oppToOCRs.put(ocr.OpportunityId, new List<OpportunityContactRole>());
            }
            oppToOCRs.get(ocr.OpportunityId).add(ocr);
        }

        // Process each Opportunity
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opp : scope) {
            if (oppToOCRs.containsKey(opp.Id)) {
                List<OpportunityContactRole> ocrs = oppToOCRs.get(opp.Id);

                // Collect Contact IDs
                Set<Id> contactIds = new Set<Id>();
                for (OpportunityContactRole ocr : ocrs) {
                    contactIds.add(ocr.ContactId);
                }

                // Build SOQL query for Contacts
                String startDateSOQL = formatDateForSOQL(calculateActiveWindowSOQLDate(opp));
                String closeDateSOQL = formatDateForSOQL(opp.CloseDate);
                String query = 'SELECT Id FROM Contact WHERE ' + 
                               lastActivityDateAPIName + ' >= :startDateSOQL AND ' +
                               lastActivityDateAPIName + ' <= :closeDateSOQL AND ' +
                               'Id IN :contactIds';

                // Query Contacts and count Active OCRs
                Integer activeOCRCount = [SELECT COUNT() FROM Contact WHERE Id IN :contactIds];

                // Update Opportunity with Active OCR count
                opp.asreporting__Active_OCRs__c = activeOCRCount;
                opportunitiesToUpdate.add(opp);
            }
        }

        // Update Opportunities
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    // Finish method to log results or perform final actions
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch completed successfully.');
    }

    // Helper method to calculate the active window start date
    private Date calculateActiveWindowSOQLDate(Opportunity opp) {
        // Convert DateTime fields to Date before using
        Date createdSOQLDate = opp.CreatedDate != null ? ((DateTime) opp.CreatedDate).date() : null;
        Date closeSOQLDate = opp.CloseDate != null ? ((DateTime) opp.CloseDate).date() : null;

        if (createdSOQLDate != null && closeSOQLDate != null) {
            return closeSOQLDate.addDays(-nod);
        }
        return createdSOQLDate != null ? createdSOQLDate : Date.today();
    }

    // Helper method to format a Date for SOQL
    private String formatDateForSOQL(Date SOQLDate) {
        return SOQLDate.year() + '-' + String.valueOf(SOQLDate.month()) + '-' + String.valueOf(SOQLDate.day());
    }

    // Invocable Method to execute this batch
    @InvocableMethod(label='Run Opportunity Active Contact Batch' description='Runs the batch process for updating Opportunities with active OCR counts.')
    public static void runBatch(List<BatchInput> inputs) {
        // Use the first input (Flow will typically provide only one)
        if (!inputs.isEmpty()) {
            BatchInput input = inputs[0];
            Database.executeBatch(
                new OpportunityActiveContactBatch(
                    input.lastActivityDateAPIName,
                    input.nod,
                    input.SOQLDate
                )
            );
        }
    }

    // Inner class for InvocableMethod inputs
    public class BatchInput {
        @InvocableVariable(label='Last Activity Date API Name' description='The API name of the Last Activity Date field' required=true)
        public String lastActivityDateAPIName;

        @InvocableVariable(label='Number of Days (Lookback)' description='The number of days to look back from CloseDate' required=true)
        public Integer nod;

        @InvocableVariable(label='Start Date (SOQL Date)' description='The start date to filter closed Opportunities' required=true)
        public Date SOQLDate;
    }
}