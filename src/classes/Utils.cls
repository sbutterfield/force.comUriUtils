/**
 *  @author: Shawn Butterfield, Salesforce.com, Inc
 *  Utilities class with general Utils used throughout different application components native to Data.com and Jigsaw processes.
 */

public without sharing class Utils {

    // TODO: Use a Custom Label instead.
    public static final String MESSAGE_CONNECTION_ERROR = 'Data.com can\'t make a connection to retrieve your data. Try again later. If the problem continues, contact Data.com support.';
    public static final String MESSAGE_TRANSIENT_ERROR = 'Data.com can\'t access the data you requested. Try again later. If the problem continues, contact Data.com support.';
    public static final String MESSAGE_GENERIC_ERROR = MESSAGE_TRANSIENT_ERROR;
    public static final String MESSAGE_UNRECOVERABLE_ERROR = 'Please contact Data.com support.';
    public static final String MESSAGE_TOKEN_FAIL = 'Verify that the Data.com token is set correctly. You might need help from a Salesforce administrator.';
    public static final String MESSAGE_OBJECT_NO_ACCESS = 'You don\'t have the required permission to make changes to this object. Contact your Salesforce administrator if you need to make modifications to this object.';
    public static final String MESSAGE_RECORD_NOT_FOUND = 'The Data.com database doesn\'t have the data you requested.';
    public static final String MESSAGE_SAVE_ERROR = 'Data.com can\'t verify this data because these fields may have been customized by your administrator. You need to contact your Salesforce administrator.';
    
    // NOTE: Order matters, we encode '&' first to avoid double encoding.
    // These arrays should have the same number of elements.
    // Using the list of entities recommended by:
    // https://www.owasp.org/index.php/XSS_%28Cross_Site_Scripting%29_Prevention_Cheat_Sheet
    // Additionally, we are escaping '\u' to prevent alternative encodings from breaking out of the
    // data context.
    private static final String[] HTML_DECODED = new String[]{ '&',     '<',    '>',    '"',      '\'',    '/',     '\\u'         };
    private static final String[] HTML_ENCODED = new String[]{ '&amp;', '&lt;', '&gt;', '&quot;', '&#39;', '&#47;', '&#92;&#117;' };
    
    // TODO: use native parsers?
    private static final String REGEX_COMPANY_ID  = '"companyId":\\s*"?(\\d+)"?\\s*,?';
    private static final String REGEX_CONTACT_ID  = '"contactId":\\s*"?(\\d+)"?\\s*,?';
    private static final String REGEX_ERROR_CODE_JSON  = '"errorCode":\\s*"(\\w+)"\\s*,?';
    private static final String REGEX_ERROR_MSG_JSON   = '"errorMsg":\\s*"([^"]+)"\\s*,?';
    private static final String REGEX_ERROR_CODE_XML   = '<jigsawStatusCode>\\s*(\\d+)\\s*</jigsawStatusCode>';
    private static final String REGEX_ERROR_MSG_XML    = '<errorMsg>(.+)</errorMsg>';
    
    // This type of PARAM_ERROR is equivalent to a record not being found.
    private static final String PARAM_ERROR_NOT_FOUND  = 'ID doesn\'t exist:';
    
    // A scheme is a letter followed by letters, digits, '+', '.', or '-'. It is followed by a ':'.
    private static final String REGEX_URL_SCHEME = '^([a-zA-Z][a-zA-Z0-9\\+\\.\\-]+):';
    
    // A valid Jigsaw_Id has only digits.
    private static final String REGEX_JIGSAW_ID = '(\\d+)';
    
    private static final String REGEX_PHONE_NUMBER = '\\W*';
    private static final Integer PHONE_NUMBER_FORMAT_LENGTH = 10;
    
    public static Boolean nullcheck(Object a){
        return (a == null);
    }
    
    /*Check equality of two objects*/
    public static Boolean equals(Object a, Object b) {
        if ((a == null && b != null) || (b == null && a != null)) return false;
        if (a == null && b == null) return true;
        if (a instanceof String && b instanceof String){
            return ((String)a).equals((String)b);
        }
        return a == b;
    }
    
    public static Boolean isEmpty(String s) {
        if (s == null || s.length() == 0) {
            return true;
        }
        else {
            return false;
        }
    }
    
    /*Crop the String to defned size*/
    public static String cutString(String str, Integer size) {
        if (str != null && str.length() > size) {
            return str.substring(0,size);
        }
        return str;
    }
    
    /*Parse Datatime from string*/
    public static Datetime parseDate(String str) {
        if (str != null && str.length() > 0) {
            String[] tokens = str.split(' ');
            if (tokens.size()>1) {
                String dateS = tokens[0] + ' ' + tokens[1];
                return DateTime.valueOf(dateS);
            }
        }
        return null;
    }
    
    /*Parse Datatime in ISO format from string*/
    public static Datetime parseISODate(String str) {
        if (str != null && str.length() > 0) {
            str = str.replaceAll('T',' ').replaceAll('Z','');
            return DateTime.valueOfGMT(str);
        }
        return null;
    }
    
    /* Checks for fls in bulk by passing the field name and attempted action on the appropriate sobject */
    public static boolean getFLS(String fname, String action, Map<String, Schema.SObjectField> sobjFieldMap) {
        // Filter out bad parameters.
        if (sobjFieldMap == null) {
            return false;
        }
        
        Schema.SObjectField field = sobjFieldMap.get(fname);
        if (field == null) {
            return false;
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (fieldDescribe == null) {
            return false;
        }
        
        boolean flsResponse;
        if ('update'.equals(action)) {
            flsResponse = fieldDescribe.isUpdateable();
        }
        else if ('create'.equals(action)) {
            flsResponse = fieldDescribe.isCreateable();
        }
        else if ('access'.equals(action)) {
            flsResponse = fieldDescribe.isAccessible();
        }
        else if ('writeRequireMasterRead'.equals(action)){
            flsResponse = fieldDescribe.isWriteRequiresMasterRead();
        }
        else {
            flsResponse = false;
        }
        
        System.debug('The describe result from fls is: ' + flsResponse);
        return flsResponse;
    }

    /**
     * This does an HTML entity encoding on the given string. See HTML_DECODED and HTML_ENCODED for
     * the complete list of replacements.
     * NOTE: Do not use this method if you don't have to! It is not a full entity encoder
     * implementation.
     */
    public static String HTMLENCODE(String input) {
        if (input == null || input.length() == 0) {
            return input;
        }
        
        Integer size = HTML_DECODED.size();
        for (Integer i = 0; i < size; i++) {
            input = input.replace(HTML_DECODED[i], HTML_ENCODED[i]);
        }
        
        return input;
    }
    
    /**
     * Safely creates a request using the given parameters.
     * Behavior:
     * - If url is null, null will be returned
     * - If body is null, it will be ignored
     * - If method is neither GET nor POST, GET will be assumed
     * - If compressed is null, no compression will be used
     * - If timeout is null, the default will be used 
     */
    public static HttpRequest createRequest(String url, String body, String method, Boolean compressed, Integer timeout) {
        if (url == null) {
            return null;
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        
        if (body != null) {
            req.setBody(body);
        }
        
        // NOTE: Method is case sensitive.
        if ('GET'.equals(method) || 'POST'.equals(method)) {
            req.setMethod(method);
        }
        else {
            req.setMethod('GET');
        }
        
        if (compressed != null) {
            req.setCompressed(compressed);
        }
        
        // HttpRequest allows a timeout value between 1ms and 60000ms.
        if (timeout != null && timeout > 0 && timeout <= 60000) {
            req.setTimeout(timeout);
        }
        
        return req;
    }
    
    /**
     * This sends the given request. If an error occurs, an ApexPage.Message will be added to the
     * messages list and null will be returned.
     */
    public static HttpResponse sendRequest(HttpRequest req, ApexPages.Message[] messages) {
        return sendRequest(req, messages, false);
    }
    
    /**
     * Pass true in the simulateError parameter to simulate an HTTP error.
     */
    private static HttpResponse sendRequest(HttpRequest req, ApexPages.Message[] messages, boolean simulateError) {
        if (req == null) {
            return null;
        }
        
        HTTPResponse res;
        try {
            if (Test.isRunningTest()) {
                if (simulateError) {
                    throw new DataDotComException('SIMULATED_ERROR');
                }
                res = new HTTPResponse();
            }
            else {
                Http http = new Http();
                res = http.send(req);
            }
        }
        catch (Exception e) {
            if (messages != null) {
                // NOTE: The exception sometimes shows the URL which could expose the token!
                // It is better not to include it in the message detail.
                messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_CONNECTION_ERROR, ''));
            }
            res = null;
        }
        
        return res;
    }
    
    /**
     * Attempts to make a request with the given URL. A JSON response is returned if we get what is
     * expected from the backend. If an error occurs during the request, an ApexPage.Message will
     * be added to the messages list and null will be returned.
     */
    private static String getJSONResponse(String url, ApexPages.Message[] messages) {
        return getJSONResponse(url, null, messages, null);
    }
    
    /**
     * Same as above but with the additional connection timeout parameter.
     */
    private static String getJSONResponse(String url, Integer timeout, ApexPages.Message[] messages) {
        return getJSONResponse(url, timeout, messages, null);
    }
    
    /**
     * Pass the desired response in the simulatedResponse parameter to simulate a response.
     */
    private static String getJSONResponse(String url, Integer timeout, ApexPages.Message[] messages, String simulatedResponse) {
        String result;
        if (Test.isRunningTest()) {
            result = simulatedResponse;
        }
        else {
            HttpRequest req = createRequest(url, null, 'GET', true, timeout);
            HTTPResponse res = sendRequest(req, messages);
            if (res == null) {
                return null;
            }
            
            result = res.getBody();
        }
        
        if (result == null || result.length() == 0) {
            if (messages != null) {
                messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_TRANSIENT_ERROR, ''));
            }
            return null;
        }
        
        // Check if an error was returned. This could come back as either JSON or XML depending on
        // where in the stack the error occurred. The load balancer responds with XML while the
        // rest of our requests receive JSON responses.
        if (!result.startsWith('{')) {
            if (messages == null) {
                return null;
            }
            
            String errorCode = Utils.getErrorCodeFromResponseString(result);
            if (errorCode == null) {
                // No clues from the response, show a generic error.
                messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_GENERIC_ERROR, ''));
            }
            else if ('TOKEN_FAIL'.equals(errorCode)) {
                // The user most likely needs to set their token.
                messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_TOKEN_FAIL, ''));
            }
            else if ('PARAM_ERROR'.equals(errorCode) || 'NOT_IMPLEMENTED'.equals(errorCode)) {
                // Unrecoverable
                String errorDetail = Utils.getErrorMsgFromResponseString(result);
                if (errorDetail == null) {
                    errorDetail = '';
                }
                if (!errorDetail.startsWith(PARAM_ERROR_NOT_FOUND)) {
                    messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_UNRECOVERABLE_ERROR, errorDetail));
                }
            }
            else {
                // Transient
                String errorDetail = Utils.getErrorMsgFromResponseString(result);
                if (errorDetail == null) {
                    errorDetail = '';
                }
                messages.add(new ApexPages.Message(ApexPages.Severity.ERROR, Utils.MESSAGE_TRANSIENT_ERROR, errorDetail));
            }
            
            return null;
        }
        
        return result;
    }
    
    /**
     * Tests if the given jigsawId is valid.
     * A jigsawId is considered valid if it is non-null, non-empty, and contains only digits.
     */
    public static boolean isJigsawIdValid(String jigsawId) {
        if (jigsawId == null || jigsawId.length() == 0) {
            return false;
        }
        
        return Pattern.matches(REGEX_JIGSAW_ID, jigsawId);
    }
    
    /**
     * This checks if the given profileId has the given perm.
     */
    public static boolean getProfilePerms(String perm, String profileId) {
        String queryString = 'SELECT p.Id, p.Name, p.' + perm + ' FROM Profile p WHERE p.Id = \'' + profileId + '\' LIMIT 1';
        List<Profile> resultset = null;
        
        try {
            resultset = Database.query(queryString);
        }
        catch (QueryException q) {
            System.debug('------------------> A query exception ocurred: ' + q);
        }
        
        if (resultset == null || resultset.size() == 0) {
            return false;
        }
        
        Profile p = resultset.get(0);
        boolean permVal = (boolean) p.get(perm);
        System.debug('The profile perm result is: ' + permVal);
        return permVal;
    }
    
    /**
     * Attempts to find the companyId from the given JSON string.
     */
    public static String getCompanyIdFromJSONString(String json) {
        return getValueFromResponseString(json, REGEX_COMPANY_ID, false);
    }
    
    /**
     * Attempts to find the contactId from the given JSON string.
     */
    public static String getContactIdFromJSONString(String json) {
        return getValueFromResponseString(json, REGEX_CONTACT_ID, false);
    }
    
    /**
     * Attempts to find an error code from the given response string.
     */
    public static String getErrorCodeFromResponseString(String response) {
        if (response == null) {
            return null;
        }
        
        if (response.startsWith('[')) {
           return getValueFromResponseString(response, REGEX_ERROR_CODE_JSON, true);
        }
        else if (response.startsWith('<')) {
            return getValueFromResponseString(response, REGEX_ERROR_CODE_XML, true);
        }
        else {
            return null;
        }
    }
    
    /**
     * Attempts to find an error message from the given response string.
     */
    public static String getErrorMsgFromResponseString(String response) {
        if (response == null) {
            return null;
        }
        
        if (response.startsWith('[')) {
           return getValueFromResponseString(response, REGEX_ERROR_MSG_JSON, true);
        }
        else if (response.startsWith('<')) {
            return getValueFromResponseString(response, REGEX_ERROR_MSG_XML, true);
        }
        else {
            return null;
        }
    }
    
    /**
     * Given a list of ApexPages.Messages, this determines if at least the min severity level is
     * present. Note that there is a similar native implementation present:
     * ApexPages.hasMessages(ApexPages.Severity) 
     * We could use that but since it only checks for the presence of specific severity types, we
     * would need to make several calls to it to achieve the same effect as this method.
     * ApexPages.Severity Enum: { FATAL, ERROR, WARNING, INFO, CONFIRM }
     */
    public static boolean messageListHasSeverity(List<ApexPages.Message> messages, ApexPages.Severity min) {
        if (messages == null || min == null) {
            return false;
        }
        
        boolean hasMessage = false;
        for (ApexPages.Message message : messages) {
            ApexPages.Severity severity = message.getSeverity();
            if (severity.ordinal() <= min.ordinal()) {
                hasMessage = true;
                break;
            }
        }
        return hasMessage;
    }
    
    /**
     * Attempts to find the value associated with the given key from the given response string. If
     * the key appears multiple times then the last value will be returned unless stopAtFirst is
     * true. If the key is not found then null is returned.
     */
    private static String getValueFromResponseString(String response, String regex, boolean stopAtFirst) {
        if (response == null || response.length() == 0) {
            return null;
        }
        
        // Use a regular expression to parse out the value from the response.
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(response);
        String value = null;
        
        if (m.find()) {
            value = m.group(1);
        }
        
        if (!stopAtFirst) {
            // Make sure we find the last possible match.
            while (m.find()) {
                value = m.group(1);
            }
        }
        
        return value;
    }
    
    /**
     * Utility which normalizes the given website to a common form for equality tests.
     * The general strategy is reduce the given value down to just a host since that's normally all
     * we care about when comparing website values.
     * @return lowercase string containing the website host or the original value if the website is
     * not a valid URL string.
     */
    public static String normalizeWebsite(String website) {
        if (website == null) {
            return website;
        }
        
        URL url;
        try {
            // If the given website does not begin with a scheme, prepend http:// to the beginning.
            // This allows us to use the single-parameter System.URL constructor.
            Pattern p = Pattern.compile(REGEX_URL_SCHEME);
            Matcher m = p.matcher(website);
            String urlString;
            if (m.find()) {
                urlString = website;
            }
            else {
                urlString = 'http://' + website;
            }
            
            url = new URL(urlString);
        }
        catch (Exception e) {
            url = null;
        }
        
        if (url == null) {
            return website;
        }
        
        String host = url.getHost();
        if (host == null || host.length() == 0) {
            return website;
        }
        
        return host.toLowerCase('en_US');
    }
    
    /**
     * Utility for test methods which creates an XML string for the given tagName and MatcherField.
     *
    public static String fieldToXml(String tagName, MatcherField field) {
        if (tagName == null || field == null || field.value == null) {
            return '';
        }
        
        String fieldValueString = HTMLENCODE(String.valueOf(field.value));
        Boolean diff = (field.diff == null) ? false : field.diff;
        return String.format('<{0} diff="{2}">{1}</{0}>',
            new List<String> { tagName, fieldValueString, String.valueOf(diff) });
    }*/
    
    /**
     * Utility for test methods which creates an XML string for the given tagName and Object.
     */
    public static String objectToXml(String tagName, Object value) {
        if (tagName == null || value == null) {
            return '';
        }
        
        return String.format('<{0}>{1}</{0}>', new List<String> { tagName, HTMLENCODE(String.valueOf(value)) });
    }
    
    /**
     * Utility for testing the equality of phone numbers.
     */
    public static Boolean phoneEquals(String phone1, String phone2) {
        String normalizedPhone1 = (phone1 == null) ? null : phone1.replaceAll(REGEX_PHONE_NUMBER, '');
        String normalizedPhone2 = (phone2 == null) ? null : phone2.replaceAll(REGEX_PHONE_NUMBER, '');
        if (equals(normalizedPhone1, normalizedPhone2)) {
            return true;
        }
        
        // For certain locales, Salesforce will format 10-digit phone numbers using the (XXX) XXX-XXXX
        // format. This is triggered when there is no leading '+' character and the country code is
        // '1'. Extension characters are appeneded to the end and are not counted.
        // See the formatPhone function at: https://na1.salesforce.com/static/022509/js/functions.js
        
        Integer length1 = (normalizedPhone1 == null) ? 0 : normalizedPhone1.length();
        Integer length2 = (normalizedPhone2 == null) ? 0 : normalizedPhone2.length();
        Boolean isccna1 = (length1 > PHONE_NUMBER_FORMAT_LENGTH && normalizedPhone1.startsWith('1'));
        Boolean isccna2 = (length2 > PHONE_NUMBER_FORMAT_LENGTH && normalizedPhone2.startsWith('1'));
        if (length2 > length1 && isccna2) {
            return normalizedPhone2.substring(1).equals(normalizedPhone1);
        }
        else if (length1 > length2 && isccna1) {
            return normalizedPhone1.substring(1).equals(normalizedPhone2);
        }
        else {
            return false;
        }
    }
    
    //---------------------------------------------------------------------------------------------
    // Tests
    //---------------------------------------------------------------------------------------------
    
    private static testmethod void testNullcheck() {
        System.assertEquals(true, nullcheck(null));
        System.assertEquals(false, nullcheck('A String'));
    }
    
    private static testmethod void testCutString() {
        System.assertEquals(null, Utils.cutString(null, 2));
        System.assertEquals('', Utils.cutString('', 2));
        System.assertEquals('12', Utils.cutString('12345', 2));
        System.assertEquals('12345', Utils.cutString('12345', 20));
    }
    
    private static testmethod void testEquals() {
        System.assertEquals(true, Utils.equals('12345', '12345'));
        System.assertEquals(false, Utils.equals('12345', '123452'));
        System.assertEquals(false, Utils.equals('12345', 12345));
        System.assertEquals(true, Utils.equals(12345, 12345));
        System.assertEquals(false, Utils.equals(12345, null));
        System.assertEquals(false, Utils.equals(null, '1'));
        System.assertEquals(true, Utils.equals(null, null));
    }
    
    private static testmethod void testIsEmpty() {
        System.assertEquals(true, Utils.isEmpty(null));
        System.assertEquals(true, Utils.isEmpty(''));
        System.assertEquals(false, Utils.isEmpty('Not Empty'));
    }
    
    private static testmethod void testParseDate() {
        System.assertEquals(null, Utils.parseDate(null));
        System.assertEquals(null, Utils.parseDate(''));
        System.assertEquals(datetime.newInstance(2004, 4, 26, 23, 24, 40), Utils.parseDate('2004-04-26 23:24:40 PDT'));
    }
    
    private static testmethod void testParseISODate() {
        System.assertEquals(null, Utils.parseISODate(null));
        System.assertEquals(null, Utils.parseISODate(''));
        System.assertEquals(datetime.newInstanceGMT(2004, 4, 26, 23, 24, 40), Utils.parseISODate('2004-04-26T23:24:40Z'));
        System.assertEquals(datetime.newInstanceGMT(2010, 6, 28, 17, 25, 58), Utils.parseISODate('2010-06-28T17:25:58Z'));
    }
    
    private static testmethod void testGetFLS() {
        System.assertEquals(false, getFLS('bogus', 'bogus', null));
        
        Profile p = [select id from profile where name='Standard User'];
        User u = new User(alias='passtest', email='passtest@testorg.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid=p.Id,
            timezonesidkey='America/Los_Angeles', username='passtest@testorg.com');
        System.runAs(u) {
            Map<String, Schema.sObjectField> sobjFieldMap = Schema.SObjectType.Account.fields.getMap();
            System.assertEquals(false, getFLS('bogus', 'bogus',  sobjFieldMap));
            System.assertEquals(false, getFLS('Phone', 'bogus',  sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'update', sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'create', sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'access', sobjFieldMap));
            System.assertEquals(false, getFLS('Phone', 'writeRequireMasterRead', sobjFieldMap));
        }
        
        // TODO: Enable if/when Salesforce fixes the bug with implicit caching (case #05320459).
        // If we run both of these tests, the second one fails because the field describes for the
        // previous user are implicitly cached and used below.  
        //p = [select id from profile where name='Read Only'];
        //u = new User(alias='limtest', email='limtest@testorg.com',
        //    emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
        //    localesidkey='en_US', profileid=p.Id,
        //    timezonesidkey='America/Los_Angeles', username='limtest@testorg.com');
        //System.runAs(u) {
        //    Map<String, Schema.sObjectField> sobjFieldMap = Schema.SObjectType.Account.fields.getMap();
        //    System.assertEquals(false, getFLS('bogus', 'bogus',  sobjFieldMap));
        //    System.assertEquals(false, getFLS('Phone', 'bogus',  sobjFieldMap));
        //   System.assertEquals(false, getFLS('Phone', 'update', sobjFieldMap));
        //    System.assertEquals(false, getFLS('Phone', 'create', sobjFieldMap));
        //    System.assertEquals(true,  getFLS('Phone', 'access', sobjFieldMap));
        //    System.assertEquals(false, getFLS('Phone', 'writeRequireMasterRead', sobjFieldMap));
        //}
    }
    
    private static testmethod void testHTMLENCODE() {
        String encodeOrig = 'Somebody\'s "Company" & Friends<br/>\\u003cbr\\u003e';
        String encodeExpected = 'Somebody&#39;s &quot;Company&quot; &amp; Friends&lt;br&#47;&gt;&#92;&#117;003cbr&#92;&#117;003e';
        System.assertEquals(null, HTMLENCODE(null));
        System.assertEquals('', HTMLENCODE(''));
        System.assertEquals(encodeExpected, HTMLENCODE(encodeOrig));
    }
    
    private static testmethod void testCreateRequest() {
        // Null URL
        HttpRequest req = createRequest(null, null, null, null, null);
        System.assertEquals(null, req);
        
        // NOTE: There is no method to retrieve the timeout.
        
        // Null Parameters
        String expectedEndpoint = 'http://www.salesforce.com';
        String expectedMethod = 'GET';
        Boolean expectedCompressed = false;
        req = createRequest(expectedEndpoint, null, null, expectedCompressed, null);
        System.assertNotEquals(null, req);
        System.assertEquals(expectedMethod, req.getMethod());
        System.assertEquals(expectedCompressed, req.getCompressed());
        
        // Valid
        expectedEndpoint = 'http://www.salesforce.com';
        expectedMethod = 'POST';
        expectedCompressed = true;
        req = createRequest(expectedEndpoint, '<matches/>', expectedMethod, expectedCompressed, 20000);
        System.assertNotEquals(null, req);
        System.assertEquals(expectedMethod, req.getMethod());
        System.assertEquals(expectedCompressed, req.getCompressed());
    }
    
    private static testmethod void testSendRequest() {
        ApexPages.Message[] messages = new List<ApexPages.Message>();
        Integer expectedMessages = 0;
        
        // Null
        System.assertEquals(null, sendRequest(null, messages));
        System.assertEquals(expectedMessages, messages.size());
        
        // Valid
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('http://www.jigsaw.com/');
        System.assertNotEquals(null, sendRequest(req, messages));
        System.assertEquals(expectedMessages, messages.size());
        
        // Simulate error
        expectedMessages++;
        System.assertEquals(null, sendRequest(req, messages, true));
        System.assertEquals(expectedMessages, messages.size());
    }
    
    private static testmethod void testGetJSONResponse() {
        ApexPages.Message[] messages = new List<ApexPages.Message>();
        Integer expectedMessages = 0;
        
        // Null/Empty response
        expectedMessages++;
        System.assertEquals(null, getJSONResponse(null, messages));
        System.assertEquals(expectedMessages, messages.size());
        Integer lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TRANSIENT_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // Same as above from a different method signature, for coverage
        expectedMessages++;
        System.assertEquals(null, getJSONResponse(null, null, messages));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TRANSIENT_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // XML error
        expectedMessages++;
        String response = '<statusResponse><errors><error><httpStatusCode>503</httpStatusCode><jigsawStatusCode>10503</jigsawStatusCode><errorMsg>Request rate per second exceeds limit. Request is dropped.</errorMsg></error></errors></statusResponse>';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TRANSIENT_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // TOKEN_FAIL
        expectedMessages++;
        response = '[{"stackTrace":"","errorMsg":"The API token is not valid.","httpStatusCode":403,"errorCode":"TOKEN_FAIL"}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TOKEN_FAIL.equals(messages.get(lastIndex).getSummary()) : false);
        
        // TOKEN_FAIL, null messages, for coverage
        System.assertEquals(null, getJSONResponse(null, null, null, response));
        
        // Unrecoverable error
        expectedMessages++;
        response = '[{"stackTrace":"","errorMsg":"endOrgId and endUserId parameters must be specified in the URL.","httpStatusCode":400,"errorCode":"PARAM_ERROR"}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_UNRECOVERABLE_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // Unrecoverable error with no errorMsg
        expectedMessages++;
        response = '[{"httpStatusCode":400,"errorCode":"PARAM_ERROR","stackTrace":""}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_UNRECOVERABLE_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // Transient error
        expectedMessages++;
        response = '[{"stackTrace":"","errorMsg":"API requests have exceeded established limits. Your request has been dropped.","httpStatusCode":503,"errorCode":"NOT_AVAILABLE"}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TRANSIENT_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // Transient error with no errorMsg
        expectedMessages++;
        response = '[{"stackTrace":"","httpStatusCode":503,"errorCode":"NOT_AVAILABLE"}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_TRANSIENT_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // Generic error
        expectedMessages++;
        response = '[{"stackTrace":"","errorMsg":"API requests have exceeded established limits. Your request has been dropped.","httpStatusCode":503}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        lastIndex = messages.size() - 1;
        System.assertEquals(true, (lastIndex >= 0) ? Utils.MESSAGE_GENERIC_ERROR.equals(messages.get(lastIndex).getSummary()) : false);
        
        // PARAM_ERROR_NOT_FOUND, no error
        response = '[{"httpStatusCode":400,"errorCode":"PARAM_ERROR","errorMsg":"ID doesn\'t exist: 123456","stackTrace":""}]';
        System.assertEquals(null, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
        
        // Valid, no error
        response = '{"totalHits":0,"companies":[]}';
        System.assertEquals(response, getJSONResponse(null, null, messages, response));
        System.assertEquals(expectedMessages, messages.size());
    }
    
    private static testmethod void testIsJigsawIdValid() {
        System.assertEquals(false, isJigsawIdValid(null));
        System.assertEquals(false, isJigsawIdValid(''));
        System.assertEquals(false, isJigsawIdValid('reset_incremental'));
        System.assertEquals(false, isJigsawIdValid('-123456'));
        System.assertEquals(true, isJigsawIdValid('123456'));
        System.assertEquals(true, isJigsawIdValid('18446744073709551615'));
    }
    
    private static testmethod void testGetProfilePerms() {
        // Read Only profile should not have access to customize application.
        Profile p = [select id from profile where name='Read Only']; 
        System.assertEquals(false, getProfilePerms('PermissionsCustomizeApplication', p.Id));
        
        // System Administrator profile should have access to customize application.
        p = [select id from profile where name='System Administrator']; 
        System.assertEquals(true, getProfilePerms('PermissionsCustomizeApplication', p.Id));
        
        // Invalid profile should not have access to anything.
        p = new Profile();
        System.assertEquals(false, getProfilePerms('PermissionsCustomizeApplication', p.Id));
    }
    
    private static testmethod void testGetCompanyIdFromJSONString() {
        String json = null;
        System.assertEquals(null, getCompanyIdFromJSONString(json));
        
        json = '';
        System.assertEquals(null, getCompanyIdFromJSONString(json));
        
        json = 'Just a string without a jigsaw id.';
        System.assertEquals(null, getCompanyIdFromJSONString(json));
        
        json = '{"totalHits":1,"companies":[{"stockSymbol":"STX","phone":"+1.831.439.2600","state":"CA","revenueRange":"> $1B","industry3":"","industry2":"","industry1":"Computers & Electronics","graveyarded":false,"city":"Scotts Valley","subIndustry1":"Consumer Electronics, Parts and Repair","subIndustry2":"","subIndustry3":"","currentLogo":"","employeeRange":"10K - 50K","name":"Seagate Technology LLC","linkInJigsaw":"www.jigsaw.com/id208926/seagate_technology_company.xhtml","fortuneRank":0,"revenue":"11400000000","zip":"95066-4544","error":null,"website":"www.seagate.com","updatedDate":"2011-06-30 23:56:01 PDT","employeeCount":60000,"sicCode":"","country":"United States","createdOn":"2004-04-26 23:23:34 PDT","ownership":"Publicly Traded","address":"920 Disc Dr","activeContacts":1737,"companyId":208926,"stockExchange":"NYSE"}]};';
        System.assertEquals('208926', getCompanyIdFromJSONString(json));
        
        json = '{"companyId":"12345","companyId":67890}';
        System.assertEquals('67890', getCompanyIdFromJSONString(json));
        
        json = '{"companyId":"12345","contactId":"67890"}';
        System.assertEquals('12345', getCompanyIdFromJSONString(json));
    }
    
    private static testmethod void testGetContactIdFromJSONString() {
        String json = null;
        System.assertEquals(null, getContactIdFromJSONString(json));
        
        json = '';
        System.assertEquals(null, getContactIdFromJSONString(json));
        
        json = 'Just a string without a jigsaw id.';
        System.assertEquals(null, getContactIdFromJSONString(json));
        
        json = '{"zip": "55438-2291","lname": "Schuster","phone": "+1.210.821.4105","subIndustry": "Telecommunications","updatedDate": "2010-11-09 11:32:34 PST","state": "MN","city": "Minneapolis","country": "United States","title": "President","contactId": "5503869","email": "guy.schuster@cingular.com","address": "8136 W 110th Street Cir","company": "AT&T Inc.","companyId": "214430","createdDate": "2008-03-09 02:37:24 PDT","fname": "Guy"};';
        System.assertEquals('5503869', getContactIdFromJSONString(json));
        
        json = '{"contactId":"12345","contactId":67890}';
        System.assertEquals('67890', getContactIdFromJSONString(json));
        
        json = '{"contactId":"12345","companyId":"67890"}';
        System.assertEquals('12345', getContactIdFromJSONString(json));
    }
    
    private static testmethod void testGetErrorCodeFromResponseString() {
        String response = null;
        System.assertEquals(null, getErrorCodeFromResponseString(response));
        
        response = '';
        System.assertEquals(null, getErrorCodeFromResponseString(response));
        
        response = 'Just a string without error codes.';
        System.assertEquals(null, getErrorCodeFromResponseString(response));
        
        response = '[{"httpStatusCode":403,"errorCode":"TOKEN_FAIL","errorMsg":"An API token is required.","stackTrace":""}]';
        System.assertEquals('TOKEN_FAIL', getErrorCodeFromResponseString(response));
        
        response = '[{"httpStatusCode":403,"errorCode":"TOKEN_FAIL","errorMsg":"An API token is required.","stackTrace":""},{"stackTrace":"","erroMsg":"API requests have exceeded established limits. Your request has been dropped.","httpStatusCode":503,"errorCode":"NOT_AVAILABLE"}]';
        System.assertEquals('TOKEN_FAIL', getErrorCodeFromResponseString(response));
        
        response = '<statusResponse>\n  <errors>\n    <error>\n    <httpStatusCode>503</httpStatusCode>\n    <jigsawStatusCode>10503</jigsawStatusCode>\n    <errorMsg>Request rate per second exceeds limit. Request is dropped.</errorMsg>\n    </error>\n  </errors>\n</statusResponse>';
        System.assertEquals('10503', getErrorCodeFromResponseString(response));
    }
    
    private static testmethod void testGetErrorMsgFromResponseString() {
        String response = null;
        System.assertEquals(null, getErrorMsgFromResponseString(response));
        
        response = '';
        System.assertEquals(null, getErrorMsgFromResponseString(response));
        
        response = 'Just a string without error codes.';
        System.assertEquals(null, getErrorMsgFromResponseString(response));
        
        response = '[{"httpStatusCode":403,"errorCode":"TOKEN_FAIL","errorMsg":"An API token is required.","stackTrace":""}]';
        System.assertEquals('An API token is required.', getErrorMsgFromResponseString(response));
        
        response = '[{"httpStatusCode":403,"errorCode":"TOKEN_FAIL","errorMsg":"An API token is required.","stackTrace":""},{"stackTrace":"","erroMsg":"API requests have exceeded established limits. Your request has been dropped.","httpStatusCode":503,"errorCode":"NOT_AVAILABLE"}]';
        System.assertEquals('An API token is required.', getErrorMsgFromResponseString(response));
        
        response = '<statusResponse>\n  <errors>\n    <error>\n    <httpStatusCode>503</httpStatusCode>\n    <jigsawStatusCode>10503</jigsawStatusCode>\n    <errorMsg>Request rate per second exceeds limit. Request is dropped.</errorMsg>\n    </error>\n  </errors>\n</statusResponse>';
        System.assertEquals('Request rate per second exceeds limit. Request is dropped.', getErrorMsgFromResponseString(response));
    }
    
    private static testmethod void testMessageListHasSeverity() {
        List<ApexPages.Message> messages = null;
        System.assertEquals(false, messageListHasSeverity(messages, null));
        
        messages = new List<ApexPages.Message>();
        System.assertEquals(false, messageListHasSeverity(messages, null));
        
        messages = new List<ApexPages.Message>{new ApexPages.Message(ApexPages.Severity.INFO, 'Not an error.')};
        System.assertEquals(false, messageListHasSeverity(messages, ApexPages.Severity.ERROR));
        
        messages = new List<ApexPages.Message>{new ApexPages.Message(ApexPages.Severity.FATAL, 'Fatal error!')};
        System.assertEquals(true, messageListHasSeverity(messages, ApexPages.Severity.ERROR));
        
        messages = new List<ApexPages.Message>{new ApexPages.Message(ApexPages.Severity.ERROR, 'Regular error!')};
        System.assertEquals(true, messageListHasSeverity(messages, ApexPages.Severity.ERROR));
    }
    
    private static testmethod void testNormalizeWebsite() {
        System.assertEquals(null, normalizeWebsite(null));
        System.assertEquals('', normalizeWebsite(''));
        
        String expectedWebsite = 'not a website!';
        System.assertEquals(expectedWebsite, normalizeWebsite('Not a website!'));
        
        expectedWebsite = 'jigsaw.com';
        System.assertEquals(expectedWebsite, normalizeWebsite('JiGSaW.com'));
        
        expectedWebsite = 'www.jigsaw.com';
        System.assertEquals(expectedWebsite, normalizeWebsite('www.jigsaw.com'));
        System.assertEquals(expectedWebsite, normalizeWebsite('http://www.jigsaw.com'));
        System.assertEquals(expectedWebsite, normalizeWebsite('http://www.jigsaw.com:80/rest/searchCompany.xml?name=www.jigsaw.com#anchor'));
        System.assertEquals(expectedWebsite, normalizeWebsite('https://www.jigsaw.com/rest/searchCompany.xml?token=00D50000000IslLEAS&name=http%3A%2F%2F%2Fwww.att.com%3Fparam%3Dvalue'));
        
        // Unknown scheme
        expectedWebsite = 'urn:example:animal:ferret:nose';
        System.assertEquals(expectedWebsite, normalizeWebsite('urn:example:animal:ferret:nose'));
    }
    
    /*private static testmethod void testFieldToXml() {
        // Null
        System.assertEquals('', fieldToXml(null, null));
        System.assertEquals('', fieldToXml('tagName', null));
        
        // Valid
        MatcherField field = new MatcherField('value', null);
        String expectedXml = '<tagName diff="false">value</tagName>';
        System.assertEquals(expectedXml, fieldToXml('tagName', field));
    }*/
    
    private static testmethod void testObjectToXml() {
        // Null
        System.assertEquals('', objectToXml(null, null));
        System.assertEquals('', objectToXml('tagName', null));
        
        // Valid
        String expectedXml = '<tagName>value</tagName>';
        System.assertEquals(expectedXml, objectToXml('tagName', 'value'));
    }
    
    private static testMethod void testPhoneEquals() {
        System.assertEquals(true, phoneEquals(null, null));
        System.assertEquals(true, phoneEquals('', ''));
        System.assertEquals(false, phoneEquals(null, ''));
        System.assertEquals(false, phoneEquals('', null));
        System.assertEquals(false, phoneEquals(null, '+1.415.901.7000'));
        System.assertEquals(false, phoneEquals('', '+1.415.901.7000'));
        
        System.assertEquals(true, phoneEquals('+1.415.901.7000', '+1.415.901.7000'));
        System.assertEquals(true, phoneEquals('415.901.7000', '(415) 901-7000'));
        System.assertEquals(true, phoneEquals('+1.415.901.7000', '(415) 901-7000'));
        System.assertEquals(false, phoneEquals('+1.415.901.7000', '+44.415.901.7000'));
    }
}