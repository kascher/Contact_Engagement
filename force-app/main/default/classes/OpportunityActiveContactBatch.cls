public class OpportunityActiveContactBatch implements Database.Batchable<SObject>, Database.Stateful {
    // Variables to store data across batch execution
    private String lastActivityDateAPIName;
    private Integer nod;
    private Date SOQLDate;

    // Wrapper class for output variables
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

    public BatchOutput output = new BatchOutput();

    // Constructor to initialize variables
    public OpportunityActiveContactBatch(String lastActivityDateAPIName, Integer nod, Date SOQLDate) {
        this.lastActivityDateAPIName = lastActivityDateAPIName;
        this.nod = nod;
        this.SOQLDate = SOQLDate;
        this.output.recordsProcessed = 0;
        this.output.errorCount = 0;
        this.output.totalJobItems = 0;
    }

    // Start method to query all closed Opportunities on or after the specified date
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, StageName, CreatedDate, CloseDate ' +
                       'FROM Opportunity ' +
                       'WHERE IsClosed = true AND CloseDate >= :SOQLDate';

        System.debug('Start Query: ' + query);
        return Database.getQueryLocator(query);
    }

    // Execute method to process a batch of Opportunities
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
        for (Opportunity opp : scope) {
            System.debug('Processing Opportunity with Id: ' + opp.Id);

            try {
                if (oppToOCRs.containsKey(opp.Id)) {
                    List<OpportunityContactRole> ocrs = oppToOCRs.get(opp.Id);

                    Set<Id> contactIds = new Set<Id>();
                    for (OpportunityContactRole ocr : ocrs) {
                        contactIds.add(ocr.ContactId);
                    }

                    String startDateSOQL = formatDateForSOQL(calculateActiveWindowSOQLDate(opp));
                    String closeDateSOQL = formatDateForSOQL(opp.CloseDate);
                    String query = 'SELECT Id FROM Contact WHERE ' + 
                                   lastActivityDateAPIName + ' >= :startDateSOQL AND ' +
                                   lastActivityDateAPIName + ' <= :closeDateSOQL AND ' +
                                   'Id IN :contactIds';

                    System.debug('Contact Query: ' + query);

                    Integer activeOCRCount = [SELECT COUNT() FROM Contact WHERE Id IN :contactIds];
                    opp.asreporting__Active_OCRs__c = activeOCRCount;
                    System.debug('Opportunity asreporting__Active_OCRs__c (after update): ' + opp.asreporting__Active_OCRs__c);
                    opportunitiesToUpdate.add(opp);
                }

                output.recordsProcessed++;
            } catch (Exception e) {
                System.debug('Error processing Opportunity with Id ' + opp.Id + ': ' + e.getMessage());
                output.errorCount++;
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
            System.debug('Updated Opportunities: ' + opportunitiesToUpdate);
        }
    }

    // Finish method to log results or perform final actions
    public void finish(Database.BatchableContext bc) {
        output.jobStatus = 'Completed';

        try {
            AsyncApexJob a = [
                SELECT Id, Status, ExtendedStatus, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
                FROM AsyncApexJob WHERE Id = :bc.getJobId()
            ];

            output.jobStatus = a.Status;
            output.errorCount += a.NumberOfErrors;
            output.totalJobItems = a.TotalJobItems;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {a.CreatedBy.Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Calculate Active Opp Contacts ' + a.Status);
            mail.setPlainTextBody('The batch Apex job processed ' + a.TotalJobItems +
                ' batches with ' + a.NumberOfErrors + ' failures. More info at Setup->Apex Jobs');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }

        System.debug('Batch completed with status: ' + output.jobStatus + ', records processed: ' + output.recordsProcessed + ', errors: ' + output.errorCount);
    }

    private Date calculateActiveWindowSOQLDate(Opportunity opp) {
        Date createdSOQLDate = opp.CreatedDate != null ? ((DateTime) opp.CreatedDate).date() : null;
        Date closeSOQLDate = opp.CloseDate != null ? ((DateTime) opp.CloseDate).date() : null;

        if (createdSOQLDate != null && closeSOQLDate != null) {
            return closeSOQLDate.addDays(-nod);
        }
        return createdSOQLDate != null ? createdSOQLDate : Date.today();
    }

    private String formatDateForSOQL(Date SOQLDate) {
        return SOQLDate.year() + '-' + String.valueOf(SOQLDate.month()) + '-' + String.valueOf(SOQLDate.day());
    }

    @InvocableMethod(label='Count Active OCRs Batch' description='Runs the batch process for updating Opportunities with active OCR counts.' category='Opportunity')
    public static List<BatchOutput> runBatch(List<BatchInput> inputs) {
        List<BatchOutput> outputs = new List<BatchOutput>();
        if (!inputs.isEmpty()) {
            BatchInput input = inputs[0];
            OpportunityActiveContactBatch batch = new OpportunityActiveContactBatch(
                input.lastActivityDateAPIName,
                input.nod,
                input.SOQLDate
            );
            Database.executeBatch(batch);

            // Create a new BatchOutput object and populate it with data
            BatchOutput resultOutput = new BatchOutput();
            resultOutput.jobStatus = batch.output.jobStatus;
            resultOutput.recordsProcessed = batch.output.recordsProcessed;
            resultOutput.errorCount = batch.output.errorCount;
            resultOutput.totalJobItems = batch.output.totalJobItems;

            outputs.add(resultOutput);
        }
        return outputs;
    }

    public class BatchInput {
        @InvocableVariable(label='Last Activity Date API Name' description='The API name of the Last Activity Date field' required=true)
        public String lastActivityDateAPIName;

        @InvocableVariable(label='Number of Days (Lookback)' description='The number of days to look back from CloseDate' required=true)
        public Integer nod;

        @InvocableVariable(label='Start Date (SOQL Date)' description='The start date to filter closed Opportunities' required=true)
        public Date SOQLDate;
    }
}