/**
 * @description Batch class to calculate and update the count of active Opportunity Contact Roles (OCRs).
 * Counts contacts based on their LastActivityDate or completed tasks/events within a specified time window.
 */
public with sharing class HistoricalAOCRBatch implements Database.Batchable<SObject>, Database.Stateful {
    public BatchOutput output;
    private Integer nod;
    private Date soqlDate;

    /**
     * @description Output object to store batch job results.
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
        this.output = new BatchOutput();
        this.output.recordsProcessed = 0;
        this.output.errorCount = 0;
        this.output.totalJobItems = 0;
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

        Map<Id, Set<Id>> oppToActiveContacts = getActiveContacts(oppIds, oppCloseDates);

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opp : scope) {
            Integer activeOCRCount = oppToActiveContacts.containsKey(opp.Id)
                ? oppToActiveContacts.get(opp.Id).size()
                : 0;
            opp.asreporting__Active_OCRs__c = activeOCRCount;
            opportunitiesToUpdate.add(opp);
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }

        // Update the output object
        this.output.recordsProcessed += scope.size();
        this.output.totalJobItems += opportunitiesToUpdate.size();
    }

    /**
     * @description Processes Opportunity Contact Roles and calculates active contacts.
     * @param oppIds Set of Opportunity IDs to process.
     * @param oppCloseDates Map of Opportunity IDs to Close Dates.
     * @return Map of Opportunity IDs to Active Contacts.
     */
    private Map<Id, Set<Id>> getActiveContacts(Set<Id> oppIds, Map<Id, Date> oppCloseDates) {
        Map<Id, Set<Id>> oppToActiveContacts = new Map<Id, Set<Id>>();

        List<OpportunityContactRole> ocrs = [
            SELECT OpportunityId, ContactId, Contact.LastActivityDate
            FROM OpportunityContactRole
            WHERE OpportunityId IN :oppIds
        ];

        for (OpportunityContactRole ocr : ocrs) {
            Id oppId = ocr.OpportunityId;
            Date closeDate = oppCloseDates.get(oppId);
            Date activityStartDate = closeDate.addDays(-nod);
            Date activityEndDate = closeDate;

            if (!oppToActiveContacts.containsKey(oppId)) {
                oppToActiveContacts.put(oppId, new Set<Id>());
            }

            if (isContactActive(new ContactActivityParamsBuilder()
                .withLastActivityDate(ocr.Contact.LastActivityDate)
                .withActivityStartDate(activityStartDate)
                .withActivityEndDate(activityEndDate)
                .withContactId(ocr.ContactId)
                .build())) {
                oppToActiveContacts.get(oppId).add(ocr.ContactId);
            }
        }

        return oppToActiveContacts;
    }

    /**
     * @description Checks if a contact is active based on activity dates.
     * @param params The parameters object containing lastActivityDate, activityStartDate, activityEndDate, and contactId.
     * @return Boolean indicating if the contact is active.
     */
    private Boolean isContactActive(ContactActivityParams params) {
        if (params.lastActivityDate != null &&
            params.lastActivityDate >= params.activityStartDate &&
            params.lastActivityDate <= params.activityEndDate) {
            return true;
        } else if (params.lastActivityDate != null && params.lastActivityDate > params.activityEndDate) {
            Integer taskEventCount = getTaskEventCount(params.contactId, params.activityStartDate, params.activityEndDate);
            return taskEventCount > 0;
        }
        return false;
    }

    /**
     * @description Class to hold parameters for contact activity.
     */
    public class ContactActivityParams {
        public Date lastActivityDate;
        public Date activityStartDate;
        public Date activityEndDate;
        public Id contactId;

        /**
         * @description Constructor to initialize the contact activity parameters.
         * @param builder The builder object containing the parameters.
         */
        public ContactActivityParams(ContactActivityParamsBuilder builder) {
            this.lastActivityDate = builder.lastActivityDate;
            this.activityStartDate = builder.activityStartDate;
            this.activityEndDate = builder.activityEndDate;
            this.contactId = builder.contactId;
        }
    }

    /**
     * @description Builder class for ContactActivityParams to avoid long parameter lists.
     */
    public class ContactActivityParamsBuilder {
        public Date lastActivityDate;
        public Date activityStartDate;
        public Date activityEndDate;
        public Id contactId;

        /**
         * @description Sets the last activity date for the contact.
         * @param lastActivityDate The last activity date to set.
         * @return The builder instance.
         */
        public ContactActivityParamsBuilder withLastActivityDate(Date lastActivityDate) {
            this.lastActivityDate = lastActivityDate;
            return this;
        }

        /**
         * @description Sets the activity start date for the contact.
         * @param activityStartDate The activity start date to set.
         * @return The builder instance.
         */
        public ContactActivityParamsBuilder withActivityStartDate(Date activityStartDate) {
            this.activityStartDate = activityStartDate;
            return this;
        }

        /**
         * @description Sets the activity end date for the contact.
         * @param activityEndDate The activity end date to set.
         * @return The builder instance.
         */
        public ContactActivityParamsBuilder withActivityEndDate(Date activityEndDate) {
            this.activityEndDate = activityEndDate;
            return this;
        }

        /**
         * @description Sets the contact ID for the contact.
         * @param contactId The contact ID to set.
         * @return The builder instance.
         */
        public ContactActivityParamsBuilder withContactId(Id contactId) {
            this.contactId = contactId;
            return this;
        }

        /**
         * @description Builds and returns a ContactActivityParams instance.
         * @return The constructed ContactActivityParams instance.
         */
        public ContactActivityParams build() {
            return new ContactActivityParams(this);
        }
    }

    /**
     * @description Counts completed tasks and events for a contact during a specific time window.
     * @param contactId The ID of the contact to check.
     * @param activityStartDate The start of the activity window.
     * @param activityEndDate The end of the activity window.
     * @return The combined count of completed tasks and events.
     */
    private Integer getTaskEventCount(Id contactId, Date activityStartDate, Date activityEndDate) {
        Integer taskCount = 0;
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

        Integer eventCount = 0;
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
     * @description Finish method to complete the batch job and send a status email instead of logging, thus avoiding PMD debug violation.
     * @param bc Batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        // Set the job status
        this.output.jobStatus = 'Completed';

        // Send an email with the completion information
        sendEmail('HistoricalAOCRBatch job completed. Records Processed: ' + this.output.recordsProcessed + ', Errors: ' + this.output.errorCount + ', Total Job Items: ' + this.output.totalJobItems);
    }

    /**
     * @description Custom method to send an email.
     * @param message The message to include in the email.
     */
    public void sendEmail(String message) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] { UserInfo.getUserEmail() }; // Get the email address of the running user
        email.setToAddresses(toAddresses);
        email.setSubject('Batch Job Completion Notification');
        email.setPlainTextBody(message);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }

    /**
     * @description Invocable method to execute the batch class.
     * @param inputs List of BatchInput objects containing batch parameters.
     * @return List of BatchOutput objects containing the results of the batch job.
     */
    @InvocableMethod(label='Count Active OCRs Batch' description='Runs the batch process for updating Opportunities with active OCR counts.' category='Opportunity')
    public static List<BatchOutput> runBatch(List<BatchInput> inputs) {
        if (!inputs.isEmpty()) {
            BatchInput input = inputs[0];
            HistoricalAOCRBatch batch = new HistoricalAOCRBatch(input.nod, input.soqlDate);
            Database.executeBatch(batch);
            return new List<BatchOutput> { batch.output };
        }
        return new List<BatchOutput>();
    }

    /**
     * @description Input object to store batch job parameters.
     */
    public class BatchInput {
        @InvocableVariable(label='Number of Days (Lookback)' description='The number of days to look back from CloseDate' required=true)
        public Integer nod;

        @InvocableVariable(label='Start Date (SOQL Date)' description='The start date to filter closed Opportunities' required=true)
        public Date soqlDate;
    }
}