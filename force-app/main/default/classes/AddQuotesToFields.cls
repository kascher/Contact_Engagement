/**
 * @description This class adds quotes to each element in a collection.
 */
public without sharing class AddQuotesToFields {
    /**
     * @description This inner class represents the input parameters.
     */
    public class Input {
        @InvocableVariable(description='Collection of records to transform')
        public List<String> fieldCollection;

        @InvocableVariable(description='Comma separated string of records to transform')
        public String fieldString;

        @InvocableVariable(description='Valid inputs are SINGLE for single quotes or DOUBLE for double quotes; Default value is SINGLE.')
        public String quoteType;
    }

    /**
     * @description This inner class represents the output parameters.
     */
    public class Output {
        @InvocableVariable(description='Collection of records transformed with quotes')
        public List<String> fieldCollection;

        @InvocableVariable(description='Comma separated string of records transformed with quotes')
        public String fieldString;
    }

    /**
     * @description This method adds quotes to each element in a collection.
     * @param inputs List of Input objects containing the parameters.
     * @return List of Output objects containing the transformed records.
     */
    @InvocableMethod(description='Add quotes to each element in a collection')
    public static List<Output> addQuotesToFieldsMethod(List<Input> inputs) {
        List<Output> outputs = new List<Output>();
        for (Input input : inputs) {
            if (input.fieldString != null && input.fieldString.length() > 0) {
                input.fieldCollection = input.fieldString.split(',');
            }
            if (input.quoteType == null) {
                input.quoteType = 'SINGLE';
            }
            List<String> transformed = new List<String>();
            for (String field : input.fieldCollection) {
                if (input.quoteType == 'DOUBLE') {
                    field = '"' + field + '"';
                } else {
                    field = '\'' + field.replace('\'', '\\\'') + '\''; // Escape single quotes
                }
                transformed.add(field);
            }
            Output output = new Output();
            output.fieldCollection = transformed;
            output.fieldString = String.join(transformed, ',');
            outputs.add(output);
        }
        return outputs;
    }
}
