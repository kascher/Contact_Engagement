/**
 * @description Batch class to calculate and update the count of active Opportunity Contact Roles (OCRs).
 * Implements Database.Batchable and Database.Stateful interfaces for batch processing.
 */
public class OpportunityActiveContactBatch implements Database.Batchable<SObject>, Database.Stateful {
    /**
     * @description Output object to store batch job results.
     */
    public BatchOutput output;

    /**
     * @description Number of days to look back from CloseDate.
     */
    private Integer nod;

    /**
     * @description Start date to filter closed Opportunities.
     */
    private Date soqlDate;

    /**
     * @description Wrapper class for output variables.
     */
    public class BatchOutput {
        @InvocableVariable(label='Job Status' description='The status of the batch job')
        public String jobStatus;

        @InvocableVariable(label='Records Processed' description='The number of records processed by the batch job')
        public Integer recordsProcessed;

        @InvocableVariable(label='Error Count' description='The number of errors encountered during the batch job')
        public Integer errorCount;

        @InvocableVariable(label='Total Job Items' description='The total number of job items processed by the batch job')
        public Integer totalJobItems;
    }
    /**
     * @description Constructor to initialize variables.
     * @param nod Number of days to look back from CloseDate.
     * @param soqlDate Start date to filter closed Opportunities.
     */

    public OpportunityActiveContactBatch(Integer nod, Date soqlDate) {
        this.nod = nod;
        this.soqlDate = soqlDate;
        this.output = new BatchOutput();
        this.output.recordsProcessed = 0;
        this.output.errorCount = 0;
        this.output.totalJobItems = 0;
    }

    /**
     * @description Start method to query all closed Opportunities on or after the specified date.
     * @param bc Batchable context.
     * @return QueryLocator for the batch job.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, StageName, CreatedDate, CloseDate ' +
                       'FROM Opportunity ' +
                       'WHERE IsClosed = true AND CloseDate >= :SOQLDate';

        return Database.getQueryLocator(query);
    }

    /**
     * @description Execute method to process a batch of Opportunities.
     * @param bc Batchable context.
     * @param scope List of Opportunities to process.
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : scope) {
            oppIds.add(opp.Id);
        }

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

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        Map<Id, Integer> contactCounts = new Map<Id, Integer>();
        
        for (AggregateResult ar : [
            SELECT OpportunityId, COUNT(Id) cnt 
            FROM OpportunityContactRole 
            WHERE OpportunityId IN :oppIds 
            GROUP BY OpportunityId
        ]) {
            contactCounts.put((Id)ar.get('OpportunityId'), (Integer)ar.get('cnt'));
        }

        for (Opportunity opp : scope) {
            Integer activeOCRCount = contactCounts.get(opp.Id);
            opp.asreporting__Active_OCRs__c = activeOCRCount != null ? activeOCRCount : 0;
            opportunitiesToUpdate.add(opp);
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

/**
 * @description Finish method to log results or perform final actions.
 * @param bc Batchable context.
 */
public void finish(Database.BatchableContext bc) {
    output.jobStatus = 'Completed';

    try {
        AsyncApexJob a = [
            SELECT Id, Status, ExtendedStatus, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob WHERE Id = :bc.getJobId()
        ];

        output.jobStatus = a.Status;
        output.totalJobItems = a.TotalJobItems;

        // Send a notification email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {a.CreatedBy.Email};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Calculate Active Opp Contacts ' + a.Status);
        mail.setPlainTextBody(
            'Batch job for calculating active Opportunity Contact Roles has completed with status: '
            + a.Status + '. Processed ' + a.JobItemsProcessed + ' batches with ' 
            + a.NumberOfErrors + ' failures. More info at Setup -> Apex Jobs.'
        );
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});

    } catch (Exception e) {
        // Handle exception while processing the finish logic
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {'admin@example.com'}); // Replace with a backup admin email
            mail.setSubject('Error in OpportunityActiveContactBatch');
            mail.setPlainTextBody('An exception occurred in the finish method: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        } catch (Exception emailException) {
           throw emailException;
        }
    }
}



    /**
     * @description Calculate the active window SOQL date for an Opportunity.
     * @param opp The Opportunity record.
     * @return The calculated SOQL date.
     */
    private Date calculateActiveWindowSOQLDate(Opportunity opp) {
        Date createdSOQLDate = opp.CreatedDate != null ? ((DateTime) opp.CreatedDate).date() : null;
        Date closeSOQLDate = opp.CloseDate != null ? ((DateTime) opp.CloseDate).date() : null;

        if (createdSOQLDate != null && closeSOQLDate != null) {
            return closeSOQLDate.addDays(-nod);
        }
        return createdSOQLDate != null ? createdSOQLDate : Date.today();
    }

    /**
     * @description Format a Date object for SOQL.
     * @param soqlDate The Date object to format.
     * @return The formatted date string.
     */
    private String formatDateForSOQL(Date soqlDate) {
        return SOQLDate.year() + '-' + String.valueOf(SOQLDate.month()) + '-' + String.valueOf(SOQLDate.day());
    }

    /**
 * @description Runs the batch process for updating Opportunities with active OCR counts.
 * @param inputs List of BatchInput objects containing the input parameters.
 * @return List of BatchOutput objects with the batch job results.
 */
    @InvocableMethod(label='Count Active OCRs Batch' description='Runs the batch process for updating Opportunities with active OCR counts.' category='Opportunity')
    public static List<BatchOutput> runBatch(List<BatchInput> inputs) {
        List<BatchOutput> outputs = new List<BatchOutput>();
        if (!inputs.isEmpty()) {
            BatchInput input = inputs[0];
            OpportunityActiveContactBatch batch = new OpportunityActiveContactBatch(
                input.nod,
                input.SOQLDate
            );
            String jobId = Database.executeBatch(batch);

            // Create a new BatchOutput object and populate it with data
            BatchOutput resultOutput = new BatchOutput();
            resultOutput.jobStatus = 'Queued (Job ID: ' + jobId + ')';
            resultOutput.recordsProcessed = batch.output.recordsProcessed;
            resultOutput.errorCount = batch.output.errorCount;
            resultOutput.totalJobItems = batch.output.totalJobItems;

            outputs.add(resultOutput);
        }
        return outputs;
    }

  /**
     * @description Input wrapper class for batch parameters.
     */
    public class BatchInput {
        @InvocableVariable(label='Number of Days (Lookback)' description='The number of days to look back from CloseDate' required=true)
        public Integer nod;

        @InvocableVariable(label='Start Date (SOQL Date)' description='The start date to filter closed Opportunities' required=true)
        public Date soqlDate;
    }
}
