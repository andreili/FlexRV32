#
#   JSON parser for Tcl.
#
#   See http://www.json.org/ && http://www.ietf.org/rfc/rfc4627.txt
#
#   Total rework of the code published with version number 1.0 by
#   Thomas Maeder, Glue Software Engineering AG
#
#   $Id: json.tcl,v 1.7 2011/11/10 21:05:58 andreas_kupries Exp $
#

namespace eval json {
    # Regular expression for tokenizing a JSON text (cf. http://json.org/)

    # tokens consisting of a single character
    variable singleCharTokens { "{" "}" ":" "\\[" "\\]" "," }
    variable singleCharTokenRE "\[[join $singleCharTokens {}]\]"

    # quoted string tokens
    variable escapableREs { "[\\\"\\\\/bfnrt]" "u[[:xdigit:]]{4}" }
    variable escapedCharRE "\\\\(?:[join $escapableREs |])"
    variable unescapedCharRE {[^\\\"]}
    variable stringRE "\"(?:$escapedCharRE|$unescapedCharRE)*\""

    # (unquoted) words
    variable wordTokens { "true" "false" "null" }
    variable wordTokenRE [join $wordTokens "|"]

    # number tokens
    # negative lookahead (?!0)[[:digit:]]+ might be more elegant, but
    # would slow down tokenizing by a factor of up to 3!
    variable positiveRE {[1-9][[:digit:]]*}
    variable cardinalRE "-?(?:$positiveRE|0)"
    variable fractionRE {[.][[:digit:]]+}
    variable exponentialRE {[eE][+-]?[[:digit:]]+}
    variable numberRE "${cardinalRE}(?:$fractionRE)?(?:$exponentialRE)?"

    # JSON token
    variable tokenRE "$singleCharTokenRE|$stringRE|$wordTokenRE|$numberRE"


    # 0..n white space characters
    set whiteSpaceRE {[[:space:]]*}

    # Regular expression for validating a JSON text
    variable validJsonRE "^(?:${whiteSpaceRE}(?:$tokenRE))*${whiteSpaceRE}$"
}

# Validate JSON text
# @param jsonText JSON text
# @return 1 iff $jsonText conforms to the JSON grammar
#           (@see http://json.org/)
proc json::validate {jsonText} {
    variable validJsonRE

    return [regexp -- $validJsonRE $jsonText]
}

# Parse JSON text into a dict
# @param jsonText JSON text
# @return dict (or list) containing the object represented by $jsonText
proc json::json2dict {jsonText {pretty false}} {
    variable prettyPrint
    variable tokenRE

    set tokens [regexp -all -inline -- $tokenRE $jsonText]
    set nrTokens [llength $tokens]
    set tokenCursor 0
    set prettyPrint $pretty
     # (just for prettyPrint=true : start from level -1 ...)
    return [parseValue $tokens $nrTokens tokenCursor -1]
}

# Parse JSON text into a pretty-print dict
# @param jsonText JSON text
# @return a pretty-print dict containing the object represented by $jsonText
proc json::json2prettydict {jsonText} {
    set res [json2dict $jsonText true]
     # remove external braces, so that result be a proper tcl-dict !
    lindex $res 0
}

proc json::TAB {n} {
    string repeat \t $n
}

# Throw an exception signaling an unexpected token
proc json::unexpected {tokenCursor token expected} {
     return -code error "unexpected token \"$token\" at position $tokenCursor; expecting $expected"
}

# Get rid of the quotes surrounding a string token and substitute the
# real characters for escape sequences within it
# @param token
# @return unquoted unescaped value of the string contained in $token
proc json::unquoteUnescapeString {token} {
    set unquoted [string range $token 1 end-1]
    return [subst -nocommands -novariables $unquoted]
}

# Parse an object member
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @param resultName name (in caller's context) of dict (or a string, if prettyPrint)
#                       representing the JSON object of which to
#                       parse the next member
proc json::parseObjectMember {tokens nrTokens tokenCursorName resultName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor
    upvar $resultName result

    set token [lindex $tokens $tokenCursor]
    incr tokenCursor

    set leadingChar [string index $token 0]
    if {$leadingChar eq "\""} {
        set memberName [unquoteUnescapeString $token]

        if {$tokenCursor == $nrTokens} {
            unexpected $tokenCursor "END" "\":\""
        } else {
            set token [lindex $tokens $tokenCursor]
            incr tokenCursor

            if {$token eq ":"} {
                set memberValue [parseValue $tokens $nrTokens tokenCursor $level]
                if { $prettyPrint } {
                    append result "$memberName $memberValue"
                } else {
                    dict set result $memberName $memberValue                
                }
            } else {
                unexpected $tokenCursor $token "\":\""
            }
        }
    } else {
        unexpected $tokenCursor $token "STRING"
    }
}

# Parse the members of an object
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @param objectDictName name (in caller's context) of dict (or a string, if prettyPrint)
#                       representing the JSON object of which to
#                       parse the next member
proc json::parseObjectMembers {tokens nrTokens tokenCursorName resultName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor
    upvar $resultName result

    while true {
        if { $prettyPrint } { append result "[TAB $level]" }   
        parseObjectMember $tokens $nrTokens tokenCursor result $level

        set token [lindex $tokens $tokenCursor]
        incr tokenCursor

        switch -exact $token {
            "," {
                if { $prettyPrint } { append result "\n" }   
            }
            "\}" {
                break
            }
            default {
                unexpected $tokenCursor $token "\",\"|\"\}\""
            }
        }
    }
}

# Parse an object
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @return parsed object (Tcl dict)
proc json::parseObject {tokens nrTokens tokenCursorName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor

    if {$tokenCursor == $nrTokens} {
        unexpected $tokenCursor "END" "OBJECT"
    } else {
        if { $prettyPrint } {
            set result "\{\n"
        } else {
            set result [dict create]        
        }
        set token [lindex $tokens $tokenCursor]

        if {$token eq "\}"} {
            # empty object
            incr tokenCursor
        } else {
            parseObjectMembers $tokens $nrTokens tokenCursor result [expr $level+1]
        }
        if { $prettyPrint } { append result "\n[TAB $level]\}" }
        return $result
    }
}

# Parse the elements of an array
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @param resultName name (in caller's context) of the list (or a string, if prettyPrint)
#                   representing the JSON array
proc json::parseArrayElements {tokens nrTokens tokenCursorName resultName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor
    upvar $resultName result

    while true {
        if { $prettyPrint } { 
            append result "[TAB $level]"
            append result [parseValue $tokens $nrTokens tokenCursor $level]
        } else {
            lappend result [parseValue $tokens $nrTokens tokenCursor $level]
        }
        if {$tokenCursor == $nrTokens} {
            unexpected $tokenCursor "END" "\",\"|\"\]\""
        } else {
            set token [lindex $tokens $tokenCursor]
            incr tokenCursor

            switch -exact $token {
                "," {
                    if { $prettyPrint } { append result "\n" }
                }
                "\]" {
                    break
                }
                default {
                    unexpected $tokenCursor $token "\",\"|\"\]\""
                }
            }
        }
    }
}


# Parse an array
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @return parsed array (Tcl list)
proc json::parseArray {tokens nrTokens tokenCursorName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor

    if {$tokenCursor == $nrTokens} {
        unexpected $tokenCursor "END" "ARRAY"
    } else {
        if { $prettyPrint } { 
            set result "\{\n" 
        } else {
            set result {}
        }
        set token [lindex $tokens $tokenCursor]

        set leadingChar [string index $token 0]
        if {$leadingChar eq "\]"} {
            # empty array
            incr tokenCursor
        } else {
            parseArrayElements $tokens $nrTokens tokenCursor result [expr $level+1]
        }
        if { $prettyPrint } { append result "\n[TAB $level]\}\n" }
        return $result
    }
}


# Parse a value
# @param tokens list of tokens
# @param nrTokens length of $tokens
# @param tokenCursorName name (in caller's context) of variable
#                        holding current position in $tokens
# @return parsed value (dict, list, string, number)
proc json::parseValue {tokens nrTokens tokenCursorName {level 0}} {
    variable prettyPrint
    upvar $tokenCursorName tokenCursor

    if {$tokenCursor == $nrTokens} {
        unexpected $tokenCursor "END" "VALUE"
    } else {
        set token [lindex $tokens $tokenCursor]
        incr tokenCursor

        set leadingChar [string index $token 0]
        switch -exact -- $leadingChar {
            "\{" {
                return [parseObject $tokens $nrTokens tokenCursor $level]
            }
            "\[" {
                return [parseArray $tokens $nrTokens tokenCursor $level]
            }
            "\"" {
                # quoted string
                set result [unquoteUnescapeString $token]
                if { $prettyPrint } { 
                    set result [list $result] 
                }
				return $result
            }
            "t" -
            "f" -
            "n" {
                # bare word: true, false or null
                return $token
            }
            default {
                # number?
                if {[string is double -strict $token]} {
                    return $token
                } else {
                    unexpected $tokenCursor $token "VALUE"
                }
            }
        }
    }   
}
