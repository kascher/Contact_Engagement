global without sharing class ActiveOCRCount {
    
    @InvocableMethod(label='Get Active OCR Count' description='Counts the number of Contacts within the specified date range and ID collection.')
    global static List<ActiveOCRCountResult> countContactsByDateRange(List<ActiveOCRCountInput> inputs) {
        // Prepare results list
        List<ActiveOCRCountResult> results = new List<ActiveOCRCountResult>();

        for (ActiveOCRCountInput input : inputs) {
            // Dynamic values for binding
            Date startDate = Date.valueOf(input.ActiveWindowStartDateSOQL);
            Date endDate = Date.valueOf(input.CloseDateSOQL);
            List<Id> fieldIds = input.fieldString;

            // Construct the SOQL query dynamically
            String query = 'SELECT COUNT() FROM Contact WHERE ' + input.LastActivityDateAPIName + 
                ' >= :startDate AND ' + input.LastActivityDateAPIName + 
                ' <= :endDate AND Id IN :fieldIds';

            // Log the constructed query structure
            System.debug('Constructed Query (with bindings): ' + query);

            // Convert List<Id> to List<String> for resolved query logging
            List<String> fieldIdsAsString = new List<String>();
            for (Id id : fieldIds) {
                fieldIdsAsString.add('\'' + String.valueOf(id) + '\'');
            }

            // Construct and log the resolved query for manual execution
            String resolvedQuery = 'SELECT COUNT() FROM Contact WHERE ' + input.LastActivityDateAPIName + ' >= \'' +
                startDate.format() + '\'' +
                ' AND ' + input.LastActivityDateAPIName + ' <= \'' +
                endDate.format() + '\'' +
                ' AND Id IN (' + String.join(fieldIdsAsString, ',') + ')';

            System.debug('Resolved Query (for manual execution): ' + resolvedQuery);

            Integer count = 0;
            try {
                // Execute the query using bind variables
                count = Database.countQuery(query);
            } catch (Exception e) {
                System.debug('Error in ActiveOCRCount: ' + e.getMessage());
            }

            results.add(new ActiveOCRCountResult(count));
        }

        return results;
    }
    
    // Input Wrapper Class
    global class ActiveOCRCountInput {
        @InvocableVariable(required=true label='Last Activity Date API Name' description='API Name of the field tracking last activity date')
        global String LastActivityDateAPIName;
        
        @InvocableVariable(required=true label='Active Window Start Date SOQL' description='Start date of the active window in SOQL format (YYYY-MM-DD)')
        global String ActiveWindowStartDateSOQL;
        
        @InvocableVariable(required=true label='Close Date SOQL' description='End date of the active window in SOQL format (YYYY-MM-DD)')
        global String CloseDateSOQL;
        
        @InvocableVariable(required=true label='Field String (Contact IDs)' description='List of Contact IDs to include in the query')
        global List<Id> fieldString; // This remains a List<Id>
    }
    
    // Output Wrapper Class
    global class ActiveOCRCountResult {
        @InvocableVariable(label='Contact Count' description='The number of Contacts matching the query criteria')
        global Integer count;
        
        global ActiveOCRCountResult(Integer count) {
            this.count = count;
        }
    }
}