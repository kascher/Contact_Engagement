/**
 * @description Batch class to calculate and update the count of active Opportunity Contact Roles (OCRs).
 * Counts contacts based on their LastActivityDate or completed tasks/events within a specified time window.
 */
public class HistoricalAOCRBatch implements Database.Batchable<SObject>, Database.Stateful {
    /**
     * @description Output object to store batch job results.
     */
    public BatchOutput output;

    private Integer nod; // Number of days to look back
    private Date soqlDate; // Start date for filtering Opportunities

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
     * @description Constructor to initialize the batch parameters.
     * @param nod Number of days to look back from the Opportunity CloseDate.
     * @param soqlDate Start date for filtering Opportunities.
     */
    public HistoricalAOCRBatch(Integer nod, Date soqlDate) {
        this.nod = nod;
        this.soqlDate = soqlDate;
    }

    /**
     * @description Start method to fetch Opportunities for processing.
     * @param bc Batchable context.
     * @return QueryLocator to fetch Opportunities.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, CloseDate ' +
                       'FROM Opportunity ' +
                       'WHERE IsClosed = true AND CloseDate >= :soqlDate';
        return Database.getQueryLocator(query);
    }

    /**
     * @description Execute method to process Opportunities and update active OCR counts.
     * @param bc Batchable context.
     * @param scope List of Opportunities to process in the current batch.
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Set<Id> oppIds = new Set<Id>();
        Map<Id, Date> oppCloseDates = new Map<Id, Date>();
        for (Opportunity opp : scope) {
            oppIds.add(opp.Id);
            oppCloseDates.put(opp.Id, opp.CloseDate);
        }

        // Fetch Opportunity Contact Roles outside of the loop
        List<OpportunityContactRole> ocrs = [
            SELECT OpportunityId, ContactId, Contact.LastActivityDate
            FROM OpportunityContactRole
            WHERE OpportunityId IN :oppIds
        ];

        // Map to store active contacts for each Opportunity
        Map<Id, Set<Id>> oppToActiveContacts = getActiveContacts(ocrs, oppCloseDates);

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opp : scope) {
            Integer activeOCRCount = oppToActiveContacts.containsKey(opp.Id) ? oppToActiveContacts.get(opp.Id).size() : 0;
            opp.asreporting__Active_OCRs__c = activeOCRCount;
            opportunitiesToUpdate.add(opp);
        }

        // Bulk update Opportunities outside of the loop
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    /**
     * @description Processes Opportunity Contact Roles and calculates active contacts.
     * @param ocrs List of Opportunity Contact Roles.
     * @param oppCloseDates Map of Opportunity IDs to Close Dates.
     * @return Map of Opportunity IDs to Active Contacts.
     */
    private Map<Id, Set<Id>> getActiveContacts(List<OpportunityContactRole> ocrs, Map<Id, Date> oppCloseDates) {
        Map<Id, Set<Id>> oppToActiveContacts = new Map<Id, Set<Id>>();

        // Collect contact IDs and check activity for each Opportunity
        for (OpportunityContactRole ocr : ocrs) {
            Id oppId = ocr.OpportunityId;
            Date closeDate = oppCloseDates.get(oppId);
            Date activityStartDate = closeDate.addDays(-nod);
            Date activityEndDate = closeDate;

            if (!oppToActiveContacts.containsKey(oppId)) {
                oppToActiveContacts.put(oppId, new Set<Id>());
            }

            // Check if the Contact has recent activity
            if (ocr.Contact.LastActivityDate != null && ocr.Contact.LastActivityDate >= activityStartDate && ocr.Contact.LastActivityDate <= activityEndDate) {
                oppToActiveContacts.get(oppId).add(ocr.ContactId);
            } else if (ocr.Contact.LastActivityDate != null && ocr.Contact.LastActivityDate > activityEndDate) {
                // For contacts with activity after the end date, query task and event counts
                Integer taskEventCount = getTaskAndEventCount(ocr.ContactId, activityStartDate, activityEndDate);

                if (taskEventCount > 0) {
                    oppToActiveContacts.get(oppId).add(ocr.ContactId);
                }
            }
        }

        return oppToActiveContacts;
    }

    /**
     * @description Counts completed tasks and events for a contact during a specific time window.
     * @param contactId The ID of the contact to check.
     * @param activityStartDate The start of the activity window.
     * @param activityEndDate The end of the activity window.
     * @return The combined count of completed tasks and events.
     */
    private Integer getTaskAndEventCount(Id contactId, Date activityStartDate, Date activityEndDate) {
        Integer taskCount = 0;
        Integer eventCount = 0;

        // Query task count
        List<AggregateResult> taskResults = [
            SELECT COUNT(Id) taskCount
            FROM Task
            WHERE WhoId = :contactId
            AND Status = 'Completed'
            AND CompletedDateTime >= :activityStartDate
            AND CompletedDateTime <= :activityEndDate
        ];
        if (!taskResults.isEmpty()) {
            taskCount = (Integer) taskResults[0].get('taskCount');
        }

        // Query event count
        List<AggregateResult> eventResults = [
            SELECT COUNT(Id) eventCount
            FROM Event
            WHERE WhoId = :contactId
            AND EndDateTime >= :activityStartDate
            AND EndDateTime <= :activityEndDate
        ];
        if (!eventResults.isEmpty()) {
            eventCount = (Integer) eventResults[0].get('eventCount');
        }

        return taskCount + eventCount;
    }

    /**
     * @description Finish method to complete the batch job.
     * @param bc Batchable context.
     */
    /**
     * This method is called when the batch job finishes.
     * 
     * @param bc The batchable context.
     */
    /**
     * @description Finish method to complete the batch job.
     * @param bc Batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        // Log the completion of the batch job
        log('HistoricalAOCRBatch job completed.', System.LoggingLevel.INFO);
    }

    /**
     * @description Custom logging method to avoid using System.debug directly.
     * @param message The message to log.
     * @param loggingLevel The logging level.
     */

    /**
     * @description Invocable method to execute the batch class.
     * @param inputs List of BatchInput objects containing batch parameters.
     */
    @InvocableMethod(label='Count Active OCRs Batch' description='Runs the batch process for updating Opportunities with active OCR counts.' category='Opportunity')
    public static void runBatch(List<BatchInput> inputs) {
        if (!inputs.isEmpty()) {
            BatchInput input = inputs[0];
            HistoricalAOCRBatch batch = new HistoricalAOCRBatch(input.nod, input.soqlDate);
            Database.executeBatch(batch);
        }
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
