/**
 * @description Test class for OpportunityActiveContactBatch.
 */
@isTest
public class OpportunityActiveContactBatchTest {
    @isTest
    static void testOpportunityActiveContactBatch() {
        // Create test data
        List<Contact> contacts = new List<Contact>();
        List<Opportunity> opportunities = new List<Opportunity>();

        for (Integer i = 0; i < 5; i++) {
            Contact contact = new Contact(
                FirstName = 'TestFirstName' + i,
                LastName = 'TestLastName' + i,
                Email = 'test' + i + '@example.com'
            );
            contacts.add(contact);
        }
        insert contacts;

        for (Integer i = 0; i < 5; i++) {
            opportunities.add(new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(-i)
            ));
        }
        insert opportunities;

        List<OpportunityContactRole> contactRoles = new List<OpportunityContactRole>();
        for (Integer i = 0; i < opportunities.size(); i++) {
            contactRoles.add(new OpportunityContactRole(
                OpportunityId = opportunities[i].Id,
                ContactId = contacts[i].Id,
                Role = 'Influencer',
                IsPrimary = true
            ));
        }
        insert contactRoles;

        // Execute batch
        Test.startTest();
        OpportunityActiveContactBatch batch = new OpportunityActiveContactBatch(30, Date.today().addDays(-30));
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify results
        for (Opportunity opp : [SELECT Id, asreporting__Active_OCRs__c FROM Opportunity WHERE Id IN :opportunities]) {
            System.assertEquals(1, opp.asreporting__Active_OCRs__c, 'Each Opportunity should have one active OCR.');
        }
    }

    @isTest
    static void testBatchFinishMethod() {
        // Execute batch
        Test.startTest();
        OpportunityActiveContactBatch batch = new OpportunityActiveContactBatch(30, Date.today().addDays(-30));
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify email notification logic
        AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE JobType = 'BatchApex' LIMIT 1];
        System.assertEquals('Completed', job.Status, 'Batch job should complete successfully.');
    }

    @isTest
    static void testInvocableMethod() {
        // Prepare input for the invocable method
        OpportunityActiveContactBatch.BatchInput input = new OpportunityActiveContactBatch.BatchInput();
        input.nod = 30;
        input.soqlDate = Date.today().addDays(-30);

        List<OpportunityActiveContactBatch.BatchInput> inputs = new List<OpportunityActiveContactBatch.BatchInput> { input };

        Test.startTest();
        List<OpportunityActiveContactBatch.BatchOutput> outputs = OpportunityActiveContactBatch.runBatch(inputs);
        Test.stopTest();

        // Verify output
        System.assertEquals(1, outputs.size(), 'One output object should be returned.');
        System.assert(outputs[0].jobStatus.contains('Queued'), 'Job status should indicate the job was queued.');
    }
}