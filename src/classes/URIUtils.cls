/**
 *  @author: Shawn Butterfield
 *  Utility class for URI (URL/URN/Email) data validation, parsing and matching
 *	Methods for pattern extraction defined by URI standard syntax, here: http://en.wikipedia.org/wiki/URI_scheme#Generic_syntax
 */
public class URIUtils {

	private static final String REGEX_URL_SCHEME = '^([a-zA-Z][a-zA-Z0-9\\+\\.\\-]+):';
	private static final String REGEX_URI_EMAIL_PATTERN = getUrlPatternString();

	public static Boolean isValidEmail(String input) {
		return null;
	}
	
	public static Boolean isValidUri(String input) {
		return null;
	}
	
	public static Boolean hasSubDomain(String input) {
		return null;
	}
	
	public static String parseSchemeFromUri(String input) {
		return null;
	}
	
	public static String ensureStartsWithHttp(String url) {
		if(url == null) {
			return url;
		}
		
		String urlString;
		try {
			Pattern p = Pattern.compile(REGEX_URL_SCHEME);
	        Matcher m = p.matcher(url);
	        if (m.find()) {
	            urlString = url;
	        }
	        else {
	            urlString = 'http://' + url;
	            return urlString;
	        }
		}
		catch(Exception e) {
			return url;
		}
		return url;
	}
	
	public static String parseDomain(String input) {
		if(input == null) {
			return input;
		}
		String domain;
		try {
			Pattern p = Pattern.compile(REGEX_URI_EMAIL_PATTERN);
			Matcher m = p.matcher(input);
			while(m.matches()) {
				/* Fix inputs with "@" character in a parameter that can screw up parsing, remove anything after the last occurence of "/" char
				*	Group0 = Input. 
				*	Group4 should be null
				*	Group2 should always have more than one dot character if this is still a URI
				* Finish by re-submitting the input, a given input may hit this logic more than once before being declared valid or invalid
				*/
				if(
					m.group(0).contains('@') && 
					(m.group(4) == null && m.group(2).countMatches('.') >= 1)
					) 
				{
					input = m.group(0).substringBeforeLast('/');
					m = m.reset(input);
				}
				// This would catch an input that has a valid email address for domain parsing in it but may contain other characteristics as well.
				else if(
						m.group(0).contains('@') 
						&& 
						(
							m.group(2) != null 
							&& 
							m.group(5) != null 
							&& 
							m.group(6) != null
						)
					) 
				{
					// Handle ccSLD's and sub-domains in email addresses
					if(
							m.group(0).countMatches('.') >= 2 
							|| 
							(m.group(5).length() <= 2 || m.group(6).length() <= 2)
						)
					{
						domain = parseOutCcSld(m, input);
						return domain;
					}
					else {
						domain = m.group(5) + '.' + m.group(6);
						domain.toLowerCase();
						return domain;
					}
				}
				// This branch will check for sub-domains and ccSLD's in a URI and parse accordingly.
				else if(m.group(0).countMatches('.') > 2 || (m.group(5).length() <= 2 || m.group(6).length() <= 2)) {
					domain = parseOutCcSld(m, input);
					return domain;
				}
				// Final branch, this just assumes a clean URI and extracts the domain
				else {
					domain = m.group(5) + '.' + m.group(6);
					domain = domain.toLowerCase();
					return domain;
				}
			}
		}
		catch (Exception e) {
			System.debug(LoggingLevel.ERROR,'An error occurred while parsing domain, returning to input stream ' +e.getStackTraceString());
			return input;
		}
		return domain;
	}
	
	public static String parseDomainWithSubdomain(String input) {
		return null;
	}
	
	public static String parseParameters(String input) {
		return null;
	}
	
	public static String parseParameter(String input, Integer n) {
		return null;
	}
	
	private static String parseOutCcSld(Matcher m, String input) {
		String domain;
		// Group 4,5,6 must not be null and always return a domain combination including Group 4 unless Group 5 is shorter than 3 chars (ie: "salesforce.co.uk" versus "www.salesforce.com")
		if(
				m.group(4) != null 
				&&
				m.group(5) != null
				&&
				m.group(6) != null
				&&
				m.group(5).length() <= 3
			)
		{
			if(m.group(4).countMatches('.') > 0) {
				domain = m.group(4).substringAfterLast('.') + '.';
			}
			else domain = m.group(4) + '.';
		}
		
		if(domain != null) {
			// Now add on the proper ccTLD and ccSLD
			domain += m.group(5) + '.' + m.group(6);
		}
		else {
			// Otherwise domain is clean with or without country code
			domain = m.group(5) + '.' + m.group(6);
		}
		
		domain.toLowerCase();
		return domain;
	}
	/**
	 *	Current URL Regex Pattern builds a match using 11 different capture groups which cover:
	 *	Scheme/Protocol: http, https, ftp(s), uri, afp, mailto, service, email address (sbutterfield@salesforce.com) etc.
	 *	Fully Qualified Scheme: http://, https://, afp://
	 *	Authority/Domain: www.salesforce.com, salesforce.com
	 *	TLD: .com, .sk
	 *	ccSLDs: .co.uk, .com.br etc
	 *	IP Address (v4)
	 *	Port Number (ICANN)
	 *	Path, Sub Path and File Name: /pub/Main.aspx
	 *	Query: ?adp=1
	 *	Fragment: .aspx, .asp, %$query
	 *	https://www.usb.regexlib.com:6553/Search.aspx?query=1#%Metadata >> yeilds:
	 *		Group0: [INPUT] https://www.usb.regexlib.com:6553/Search.aspx?query=1#%Metadata
	 *		Group1: https
	 *		Group2: [No Match]
	 *		Group3: [No Match]
	 *		Group4: www.usb
	 *		Group5: regexlib
	 *		Group6: com
	 *		Group7: 6553
	 *		Group8: [No Match]
	 *		Group9: /Search.aspx
	 *		Group10: query=1
	 *		Group11: %Metadata
	 */
	 
	private static String getURLPatternString() {
		String result;
		try {
			Blob content = [Select Body from StaticResource where Name = 'REGEX_URI_EMAIL_PATTERN'].Body;
			if(content.size() > 0) {
				result = content.toString();
			}
		}
		catch(Exception e) {
			System.debug(LoggingLevel.ERROR,'Unable to retrieve REGEX_URI_EMAIL_PATTERN as a string from static resources.' +e);
		}
		return result;
	}
}