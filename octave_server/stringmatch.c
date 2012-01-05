/* Extracted from tclUtil.c

Copyright (c) 1987-1993 The Regents of the University of California.
Copyright (c) 1994-1998 Sun Microsystems, Inc.
Copyright (c) 2001 by Kevin B. Kenny.  All rights reserved.


This software is copyrighted by the Regents of the University of
California, Sun Microsystems, Inc., Scriptics Corporation, ActiveState
Corporation and other parties.  The following terms apply to all files
associated with the software unless explicitly disclaimed in
individual files.

The authors hereby grant permission to use, copy, modify, distribute,
and license this software and its documentation for any purpose, provided
that existing copyright notices are retained in all copies and that this
notice is included verbatim in any distributions. No written agreement,
license, or royalty fee is required for any of the authorized uses.
Modifications to this software may be copyrighted by their authors
and need not follow the licensing terms described here, provided that
the new terms are clearly indicated on the first page of each file where
they apply.

IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
MODIFICATIONS.

GOVERNMENT USE: If you are acquiring this software on behalf of the
U.S. government, the Government shall have only "Restricted Rights"
in the software and related documentation as defined in the Federal 
Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
are acquiring the software on behalf of the Department of Defense, the
software shall be classified as "Commercial Computer Software" and the
Government shall have only "Restricted Rights" as defined in Clause
252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
authors grant the U.S. Government and others acting in its behalf
permission to use and distribute the software in accordance with the
terms specified in this license. 

 */


/*
 *----------------------------------------------------------------------
 *
 * StringCaseMatch --
 *
 *	See if a particular string matches a particular pattern.
 *	Allows case insensitivity.
 *
 * Results:
 *	The return value is 1 if string matches pattern, and
 *	0 otherwise.  The matching operation permits the following
 *	special characters in the pattern: *?\[] (see the manual
 *	entry for details on what these mean).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

#include <ctype.h> /* PAK: need tolower declaration */
#define CONST const
#define UCHAR (unsigned char)

/* Note: restore original code from the Tcl tree if you want unicode
 * support. */

int
StringCaseMatch(string, pattern, nocase)
    CONST char *string;		/* String. */
    CONST char *pattern;	/* Pattern, which may contain special
				 * characters. */
    int nocase;			/* 0 for case sensitive, 1 for insensitive */
{
    int p /*, charLen*/;  /* PAK: unused */
    /* CONST char *pstart = pattern; */  /* PAK: unused */
    char ch1, ch2;
    
    while (1) {
	p = *pattern;
	
	/*
	 * See if we're at the end of both the pattern and the string.  If
	 * so, we succeeded.  If we're at the end of the pattern but not at
	 * the end of the string, we failed.
	 */
	
	if (p == '\0') {
	    return (*string == '\0');
	}
	if ((*string == '\0') && (p != '*')) {
	    return 0;
	}

	/*
	 * Check for a "*" as the next pattern character.  It matches
	 * any substring.  We handle this by calling ourselves
	 * recursively for each postfix of string, until either we
	 * match or we reach the end of the string.
	 */
	
	if (p == '*') {
	    /*
	     * Skip all successive *'s in the pattern
	     */
	    while (*(++pattern) == '*') {}
	    p = *pattern;
	    if (p == '\0') {
		return 1;
	    }
	    ch2 = (nocase ? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
	    while (1) {
		/*
		 * Optimization for matching - cruise through the string
		 * quickly if the next char in the pattern isn't a special
		 * character
		 */
		if ((p != '[') && (p != '?') && (p != '\\')) {
		    if (nocase) {
			while (*string) {
			    ch1 = *string;
			    if (ch2==ch1 || ch2==tolower(ch1)) break;
			    string++;
			}
		    } else {
			while (*string) {
			    ch1 = *string;
			    if (ch2==ch1) break;
			    string++;
			}
		    }
		}
		if (StringCaseMatch(string, pattern, nocase)) {
		    return 1;
		}
		if (*string == '\0') {
		    return 0;
		}
		string++;
	    }
	}

	/*
	 * Check for a "?" as the next pattern character.  It matches
	 * any single character.
	 */

	if (p == '?') {
	    pattern++;
	    string++;
	    continue;
	}

	/*
	 * Check for a "[" as the next pattern character.  It is followed
	 * by a list of characters that are acceptable, or by a range
	 * (two characters separated by "-").
	 */

	if (p == '[') {
	    char startChar, endChar;

	    pattern++;
	    ch1 = (nocase ? tolower(UCHAR(*string)) : UCHAR(*string));
	    string++;
	    while (1) {
		if ((*pattern == ']') || (*pattern == '\0')) {
		    return 0;
		}
		startChar = 
			(nocase ? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
		pattern++;
		if (*pattern == '-') {
		    pattern++;
		    if (*pattern == '\0') {
			return 0;
		    }
		    endChar = 
		      (nocase ? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
		    pattern++;
		    if (((startChar <= ch1) && (ch1 <= endChar))
			    || ((endChar <= ch1) && (ch1 <= startChar))) {
			/*
			 * Matches ranges of form [a-z] or [z-a].
			 */

			break;
		    }
		} else if (startChar == ch1) {
		    break;
		}
	    }
	    while (*pattern != ']') {
	        if (*pattern == '\0') {
		    pattern--;
		    break;
		}
		pattern++;
	    }
	    pattern++;
	    continue;
	}

	/*
	 * If the next pattern character is '\', just strip off the '\'
	 * so we do exact matching on the character that follows.
	 */

	if (p == '\\') {
	    pattern++;
	    if (*pattern == '\0') {
		return 0;
	    }
	}

	/*
	 * There's no special character.  Just make sure that the next
	 * bytes of each string match.
	 */

	ch1 = *string++;
	ch2 = *pattern++;
	if (nocase) {
	    if (tolower(ch1) != tolower(ch2)) {
		return 0;
	    }
	} else if (ch1 != ch2) {
	    return 0;
	}
    }
}
