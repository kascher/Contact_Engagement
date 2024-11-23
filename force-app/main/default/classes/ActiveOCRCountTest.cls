@isTest
public class ActiveOCRCountTest {
    @isTest
    static void testCountContactsByDateRange() {
        // Step 1: Create unique test data
        // Insert unique Contacts
        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe+test1@example.com');
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', Email = 'jane.smith+test2@example.com');
        insert new List<Contact>{ contact1, contact2 };

        // Create unique completed Tasks
        Task task1 = new Task(
            Subject = 'Call with John',
            WhoId = contact1.Id,
            ActivityDate = Date.today().addDays(-2), // Within the date range
            Status = 'Completed'
        );
        Task task2 = new Task(
            Subject = 'Follow-up with Jane',
            WhoId = contact2.Id,
            ActivityDate = Date.today().addDays(-10), // Outside the date range
            Status = 'Completed'
        );
        insert new List<Task>{ task1, task2 };

        // Step 2: Prepare input parameters for the invocable method
        ActiveOCRCount.ActiveOCRCountInput input = new ActiveOCRCount.ActiveOCRCountInput();
        input.LastActivityDateAPIName = 'LastActivityDate'; // Standard field for last activity

        // Format dates explicitly in 'yyyy-MM-dd'
        input.ActiveWindowStartDateSOQL = String.valueOf(Date.today().addDays(-5).year()) + '-' +
                                          String.valueOf(Date.today().addDays(-5).month()) + '-' +
                                          String.valueOf(Date.today().addDays(-5).day());
        input.CloseDateSOQL = String.valueOf(Date.today().year()) + '-' +
                              String.valueOf(Date.today().month()) + '-' +
                              String.valueOf(Date.today().day());
        input.fieldString = new List<Id>{ contact1.Id, contact2.Id };

        List<ActiveOCRCount.ActiveOCRCountInput> inputs = new List<ActiveOCRCount.ActiveOCRCountInput>{ input };

        // Step 3: Execute the method
        Test.startTest();
        List<ActiveOCRCount.ActiveOCRCountResult> results = ActiveOCRCount.countContactsByDateRange(inputs);
        Test.stopTest();

        // Step 4: Validate results
        System.assertEquals(1, results.size(), 'Only one result should be returned.');
        System.assertEquals(1, results[0].count, 'The count should be 1 as only one contact is within the date range.');
    }
}