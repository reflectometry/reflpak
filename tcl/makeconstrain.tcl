#!/data/people/pkienzle/bin/tclsh

#@(#) makeconstrain     Version 2.0    02/04/2004

#Define some functions.  Main code starts far below! (Look for TCL MAIN BEGINS)

proc substr {string list} {
   string range $string [lindex $list 0] [lindex $list 1]
}
#puts [info body substr]


#@(#) decase	Version 2.1	12/04/2003
namespace eval ::decase {
proc script2C {script} {
   variable decap;

   # Handles newlines in quotes, and multiline comments and preprocessor
   # directives (but not #if .. #endif weirdisms)
   set freetext {['"/\B\n]}; # delimiters: quote, backslash, C comment, newline
   set comment  {[*\B\n]};   # delimiters: backslash, C comment, newline
   set string   {["\B]};     # delimiters: backslash, double quote
   set char     {['\B]};     # delimiters: backslash, single quote

   set searchfor $freetext;
   set pending "";
   set processed "";
   set remainder $script
   set preproc [regexp {^\s*#} $remainder];
   set script ""

   # Force termination of script with a newline
   if {[string index $remainder end] ne "\n"} {append remainder "\n"}

   # Life is a little easier if we guarantee one white space,
   # one blank line, and one more white space at the end of the script.
   append remainder " \n ";

   while {[regexp -indices "($searchfor)(.|\n)" $remainder {`'} found nextchar]} {
      set leader [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found]
      set nextchar [substr $remainder $nextchar]
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end];
      append pending $leader;
      switch -exact -- $found {
         "\\" {
            # Process escaped characters
            append pending "\\$nextchar";
            set nextchar "";
         }
         {"} {
            # Process quoted material
            if {$searchfor eq $string} {
               set $searchfor $resume;
            } else {
               eval $decap;
               set resume $freetext;
               set searchfor $string;
            }
            append processed $pending$found;
            set pending "";
         }
         "'" {
            # Process quoted material
            if {$searchfor eq $char} {
               set searchfor $resume
            } else {
               eval $decap;
               set resume $searchfor;
               set searchfor $char;
            }
            append processed $pending$found;
            set pending "";
         }
         "\n" {
            set remainder $nextchar$remainder
            set nextchar ""
            if {$searchfor eq $freetext} {eval $decap};
            append processed $pending;
            # Append ; to ends of statements.  Statements are identified by
            #    1) Not being in a preprocessor directive, and
            #    2) Having the line end with optional whitespace and
            #       a) the ++ operator
            #       b) the -- operator
            #       c) the end of:
            #          1) an array index []
            #          2) a character constant ''
            #          3) a floating point number with trailing decimal point
            #          4) a name or number token
            #          5) a function call () or grouped expression
            # We barf on and (wrongfully) stick a ; at the end of
            #   1) if, for, do, while or switch statements which don't open a
            #      block on the same line.  You must open a block, stick
            #      \ at the end of the line, or put your code on the same line.
            #   2) function definitions (turns it into a prototype).  If you
            #      stick a \ at the end of the line and then put a blank line
            #      before the function block, it will work.
            #   3) nested () where ) terminates the line, but not the
            #      expression.
            #   4) structure/union operator . at the end of the line
            #   5) certain ill-advised, but valid constructions.  The
            #      compiler will (probably|hopefully) complain when it
            #      encounters the misplaced ;
            # To be safe, make sure every non-blank line which doesn't
            #   terminate a statement ends with one of the following
            #   punctuators: { , \ }
            # To balance [] matching for vi, keep this [ here
            if {!$preproc && [regexp {(\+\+|--|[]'.\w)])\s*$} $processed]} {
               append processed ";"
            }
            # To balance {} matching for vi, keep these \{\{ here
            # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
            # KEEP THOSE BACKSLASHES THERE
            # Make sure blocks are terminated with ; before the block ends.
            # It may barf on certain aggregate initializations.
            regsub "\}\\s*\$" $processed ";\}" processed;
            append script "$processed\n";
            set pending "";
            set processed "";
            set preproc [regexp {^\s*#} $remainder];
         }
         "/" {
            if {$nextchar eq "*"} {
               # Beginning of C comment
               set searchfor $comment;
               eval $decap;
               append processed "$pending/*";
               set pending "";
               set nextchar "";
            } else {
               # Ordinary division sign
               append pending "/";
            }
         }
         "*" {
            if {$nextchar eq "/"} {
               # End of C comment
               set searchfor $freetext;
               append processed "$pending*/";
               set pending "";
               set nextchar "";
            } else {
              # Ordinary multiplication sign
              append pending "*";
            }
         }
      }
      set remainder $nextchar$remainder;
   }
   append script $processed$pending$remainder
   # Remove the whitespace we added
   set script [string replace $script end-2 end];
}
#puts [info body script2C]


# Argv will be a list looking much like
# list QC 0 D 16 RO 32 - BI 48 BK 49 - NT NM NB NR - DELS
# Fittable layer parameter names and indices are listed before the first -
# Fittable non-layer parameter names and indices are listed before the second -
# Non-fittable parameter names are listed before the third -
# Non-fittable state variables for the minimization algorithm are listed after the third -
# Only the layer-parameters are aggregate variables.  All others are scalars.
# Non-fittable parameters are passed by value.
# Fittable parameters are passed by reference to the appropriate array.
proc makeCDefs {argv} {
   variable decap;

#  set decap "{";
   set decap {};
   set defines {};
   set scalar 0;
   set itemComplete 1
   foreach {item} $argv {
      if {$item eq "-"} {
         incr scalar;
         set itemComplete 1;
      } else {
         # Original Perl code was lookahead with extra shift
         # Now with Tcl we must do look behind
         if {$itemComplete} {set token $item} else {set index $item};
         if {$scalar < 2} {set itemComplete [expr {!$itemComplete}]};
         if {$itemComplete} {
            if {!$scalar} {
               # Create #defines for aggregate variables
               append defines "#define ${token}(var)(_a\[$index + (var)])\n";
               append decap "regsub -all -nocase {\\y${token}(\[0-9]+)\\y} \$pending {${token}(\\1)} pending;\n"
            }
            # Create #defines for scalar variables
            if {$scalar == 1} {append defines "#define $token (_a\[$index])\n"};
            append decap "regsub -all -nocase {\\y$token\\y} \$pending {$token} pending;\n";
         }
      }
   }
#  append decap "}";
#puts $decap
#puts $defines
   set defines
}
#puts [info body makeCDefs]
}
# End of ::decase namespace module


##############################################################################
#@(#) ctopretcl	Version 1.0
namespace eval ::ctopretcl {
# The following transformations are applied:
# 
# C comments /* ... */ will be rewritten with ;# as the opening comment
# characters.  Each unescaped newline inside the comment will be followed
# by # to continue the comment on the next line. If the terminating */ does
# not come at the end of the line (intervening whitespace is optional),
# the */ is replaced with newline.  The combination \*/ will not terminate
# the comment--the backslash will be treated as an escape character.
#
# The characters [ ] and { } when occurring inside strings or comments
# will be receive an escaping \ for Tcl if they are not otherwise escaped.
#
# for(;;) loops will be rewritten as for {} {} {}
# if() and while() will be rewritten as if {} and while {}
#
# The assignment operators (e.g., +=) will be rewritten as
# *** = *** +.
#
# A newline is appended to the end of the script if it doesn't come with one
# already.


proc CtoPreTcl {script} {
   variable checkExt;

   set freetext {['"/\B(\n]};   # delimiters: quote, backslash, C comment,
                                # parens, newline
   set extkey   {['"/\B(;)\n]}; # delimiters: quote, backslash, C comment,
                                # parens, statement end, newline
   set comment  {[][{}*\B\n]};  # delimiters: brackets, braces, backslash,
                                # newline, C comment
   set string   {[][{}"\B]};    # delimiters: brackets, braces, backslash,
                                # double quote
   set char     {['\B]};        # delimiters: backslash, single quote

   set searchfor $freetext;
   set extended 0;
   set nest 0;

   set processed "";
   set pending "";
   set remainder $script;
   set inlinecomment 0;

   # Force termination of script with a newline
   if {[string index $remainder end] ne "\n"} {append remainder "\n"}

   # Life is a little easier if we guarantee one white space,
   # one blank line, and one more white space at the end of the script.
   append remainder " \n ";

   while {[regexp -indices "($searchfor)(.|\n)" $remainder {`'} found nextchar]} {
      set leader [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found]
      set nextchar [substr $remainder $nextchar]
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end]
      # Force line break if C comment did not come at end of line
      if {$inlinecomment} {
         if {$found ne "\n" || ![regexp {^[\s]*$} $leader]} {
            append pending "\n"
         }
         set inlinecomment 0;
      }
      append pending $leader;
      switch -exact -- $found {
         "\\" {
            # Process escaped characters
            append pending "\\$nextchar";
            set nextchar "";
         }
         {"} {
            # Process quoted material
            if {$searchfor eq $string} {
               set searchfor $resume;
            } else {
               eval $checkExt;
               set resume $searchfor;
               set searchfor $string;
            }
            append processed $pending$found;
            set pending "";
         }
         "'" {
            # Process quoted material
            if {$searchfor eq $char} {
               set searchfor $resume;
            } else {
               eval $checkExt;
               set resume $searchfor;
               set searchfor $char;
            }
            append processed $pending$found;
            set pending "";
         }
         "\{" - "\}" - "\[" - "\]" {
            # Unescaped Tcl groupers in string: Add escaping
            # NB: assumes found only when $searchfor is $string or $comment
            append pending "\\$found";
         }
         "\n" {
            if {($searchfor eq $freetext) || ($searchfor eq $extkey)} {eval $checkExt}
            append processed "$pending\n";
            # Automatically extend multiline comments
            if {$searchfor eq $comment} {append processed "#"}
            set pending "";
         }
         "/" {
            if {$nextchar eq "*"} {
               # Beginning of C comment
               set resume $searchfor;
               set searchfor $comment;
               eval $checkExt;
               append processed "$pending;#";
               set pending "";
               set nextchar "";
            } else {
               # Ordinary division sign
               append pending "/";
            }
         }
         "*" {
            if {$nextchar eq "/"} {
               # End of C comment
               set searchfor $resume;
               append processed "$pending ";
               set pending "";
               set nextchar "";
               set inlinecomment 1;
            } else {
               # Ordinary multiplication sign
               append pending "*";
            }
         }
         "\(" {
            if {$extended} {
               # Nested parenthetical expression
               incr nest;
               append pending "(";
            } else {
               eval $checkExt;
               append processed $pending;
               if {$extended} {
                  set resume $searchfor;
                  set searchfor $extkey;
                  set nest 0;
               }
               set pending [expr {$extended ? " \{" : "("}];
               # To balance {} matching for vi, keep this \} here
               # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
               # KEEP THAT BACKSLASH THERE
            }
         }
         default {
            if {[regexp {[;)]} $found]} {
               if {$nest} {
                  # Ordinary terminator
                  append pending $found;
                  if {!($found eq ";")} {incr nest -1}
               } else {
                  # Extended keyword is being processed
                  # To balance {} matching for vi, keep this \{ here
                  # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
                  # KEEP THAT BACKSLASH THERE
                  append pending "\}";
                  incr extended -1;
                  if {$extended} {
                     append pending " \{";
                     # To balance {} matching for vi, keep this \} here
                     # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
                     # KEEP THAT BACKSLASH THERE
                  } else {
                     set searchfor $resume
                  }
               }
            }
         }
      }
      set remainder $nextchar$remainder;
   }
   append processed $pending$remainder;
   # Remove the white spaces we added
   set processed [string replace $processed end-2 end];
   # Make sure script doesn't end with a backslash
   if {[regexp {\B\s?$} $processed]} {append processed " \n"}
   set script $processed;
}
#puts [info body CtoPreTcl];


proc makePreChecks {argv} {
   variable checkExt;

   set opeq {[-+*\\\/^&]};          # operators which can also assign lvalues
#  append checkExt "puts \"Decapping \\\"\$pending\\\"\";\n";
   append checkExt {set extended [expr {[regexp {(if|while|for)\s*$} $pending] + 2*([regexp {for\s*$} $pending])}];}
   append checkExt "\n";
   append checkExt {regsub -all {([^{};, 	]+)(\s*)([-+*/^&])=} $pending {\1\2 = \1 \3} pending;}
   append checkExt "\n";
#puts "$checkExt";
}
#puts [info body makePreChecks]
}
# End of ::ctopretcl namespace module


##############################################################################
#@(#) ctotcl	Version 1.0
namespace eval ::ctotcl {
proc PreTcltoTcl {script} {
;
   variable block;
   variable bracenest;
   variable char;
   variable comment;
   variable eops;
   variable freetext;
   variable lvalue;
   variable parennest;
   variable quotes;
   variable string;
   variable subexpr;
   variable tclspace;

   set quotes   {'"\B};          # delimiter: single or double quote, backslash
   set eops     {!%&*/:<=>?^|~}; # delimiter: expr operators
   set freetext "\[$quotes#{};]";# delimiters: quotes, Tcl comment, braces or
                                 # statement terminator
   set block    "\[$quotes#{}]"; # delimiters: quotes, Tcl comment, braces
   set comment   {[\n\B]};       # delimiters: backslash, newline (explicit)
   set string   {["\B]};         # delimiters: backslash, double quote
   set char     {['\B]};         # delimiters: backslash, single quote
   set lvalue   "\[$quotes=]";   # delimiters: quotes, equal sign
   set subexpr  "\[-+$eops${quotes}()\\\[\\]eE]";
                                 # delimiters: expr ops, quotes, parens,
                                 # brackets, floating point exponentials
   set tclspace {[\s\B]};        # delimiters: space, backslash


   set bracenest 0;
   set parennest 0;
   Reblock $script;
}
#puts [info body PreTcltoTcl]

# Takes two arguments: a script to run just before it sticks the opening
# delimiter to $pending and a script to run just after it sticks the closing
# delimeter to $pending. (The latter requires uncommenting the appropriate
# lines.)
proc tokenQuote {prescript {postscript {}}} {
   variable string;
   variable char;
   upvar found found nextchar nextchar pending pending resume resume searchfor searchfor

   switch -exact -- $found {
      "\\" {
         # Process escaped characters
         if {($searchfor ne $string) && ($searchfor ne $char)} {uplevel $prescript}
         append pending \\$nextchar;
         set nextchar "";
   #     if {($searchfor ne $string) && ($searchfor ne $char)} {uplevel $postscript}
      }
      {"} {
         # Process quoted material
         if {$searchfor eq $string} {
            set searchfor $resume;
         } else {
            set resume $searchfor;
            set searchfor $string;
            uplevel prescript;
         }
         append pending $found;
   #     if {$searchfor ne $string} {uplevel $prescript}
      }
      "'" {
         # Process quoted material
         if {$searchfor eq $char} {
            set searchfor $resume;
         } else {
            set resume $searchfor;
            set searchfor $char;
            uplevel $prescript;
         }
         append pending $found;
   #     if {$searchfor ne $char} {uplevel $postscript}
      }
   }
}
#puts [info body tokenQuote]

proc Reblock {script} {
   variable block;
   variable bracenest;
   variable comment;
   variable freetext;
   variable quotes;

#  local($processed, $pending, $remainder, $nextchar) = ('', '', $_[0], '');
   set processed "";
   set pending "";
   set remainder $script;
   set nextchar "";
#  local($searchfor, $found, $resume) = ($freetext, '', '');
   set searchfor $freetext;
   set found "";
   set resume "";
#  local($inblock, $nest) = (0, 0);
   set inblock 0;
   set nest 0;
   set extended 0;

   set needbrace ""

   while {[regexp -indices "($searchfor)(.|\\n)" $remainder {`'} found nextchar]} {
      append pending [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found]
      set nextchar [substr $remainder $nextchar]
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end]
      if {[regexp "\[$quotes]" $found]} {
         tokenQuote "" "";
      } else {
         switch -exact -- $found {
            "#" {
               # Beginning of Tcl comment
               set pending [CtoTcl "comment" $pending];
               append processed $pending$needbrace;
               set resume $searchfor;
               set searchfor $comment;
               set pending "#";
            }
            "\n" {
               # End of Tcl comment
               set searchfor $resume;
               append processed "$pending\n";
               set pending "";
            }
            "\{" {
               set pending [CtoTcl "preblock" $pending];
               append processed $pending$needbrace$found;
               set pending "";
               set inblock 1;
               incr bracenest;
            }
            "\}" {
               # Block is terminated
               # Whole block is in $pending
               set pending [CtoTcl "block" $pending];
               append processed $pending$needbrace$found;
               set pending "";
               set inblock 0;
               incr bracenest -1;
            }
            ";" {
               # Statement in $pending
               set pending [CtoTcl "statement" $pending];
               append processed $pending$found$needbrace;
               set pending "";
            }
         }
      }
      set remainder $nextchar$remainder;
   }
   # End of line
   # Remainder always contains a newline (we never chopped), unless
   #    that newline was escaped with \ (Need space, or comment continues!)
   append pending $remainder;
   if {$searchfor eq $comment} {
      append processed $pending;
      set pending "";
      set searchfor $resume;
   }

   # $processed is still empty if no blocks found, avoid infinite recursion
   if {$pending ne "" && $processed ne ""} {set pending [CtoTcl "postblock" $pending]}
   append processed $pending$needbrace;
   set processed;
}
#puts [info body Reblock]


# Rewrite PseudoTcl code as Tcl code, one statement at a time.
# A statement is everything between an unescaped {, ;, or } until the next
# unescaped {, ;, or }.  Quoting is considered an escapement.
#
# A keyword is a statement consisting of exactly one word.  Exceptions
# consist of return statements, if and else clauses which do not open
# new blocks, and statements consisting only of ++ or -- applied to a
# single operand.  Only these exceptions are understood.  A statement
# consisting of no = and more than one word is thought to be a declaration,
# or prototype.  Each line of such a statement is commented.
#
# If an if clause which does not begin a block is followed on the next
# line by an else clause, the else clause will not be recognized as part of
# the if clause if the intervening newline is not escaped.  It is advised
# that all for, while, if, and else clauses be blocked, both for the C
# implementation as well as the Tcl implementation.
#
# Words not followed by ( are considered variables and will have $ prepended
# to them.  If the resulting expression is found to be on the lefthand
# side of an =, the leading $ will be removed.
#
# The equals sign does not respect nesting of parentheses to any level.
# A = B = C is understood, A = (B = C) is not, nor is A = sin(B=C).
#
# We fail to comment declarations which initialize variables.  Do not initialize
# your variables in your declarations.  Initialize them in a separate statement.
#
# for(;;) loops will have been rewritten as for {} {} {}
# if() and while() will have been rewritten as if {} and while {}
# The assignment operators (e.g., +=) will have been rewritten as
# *** = *** +.
#
# The statement 'else if' is collapsed to elseif.  PseudoTcl whitespace
# is allowed between the else and the if.  PseudoTcl whitespace consists
# of whitespace or escaped whitespace.
#
# Single statements after for, if, else, (and now elseif), not enclosed
# in {} get {} around them automatically.
#
# The switch statement is not detected and will cause the invocation of
# the output to fail.  Constructing a switch statement according to Tcl
# switch syntax, but using C-style expressions probably will correctly
# fool the translator.  Tcl switch requires default to be the last case
# and places an implicit break before each match test.
#
# Access to mlayer parameters is detected.  Nonmodifiable mlayer parameters
# (e.g., NL, NTL, NML, NBL, NR) are retrieved once at the beginning
# of an invocation of the output, and thereafter are treated as any
# other variable.  Modifiable mlayer parameters, e.g., D(1), RO(j+2),
# are mapped to calls to the gmlayer procedure.  The expression inside ()
# is passed through Tcl expr only if a Tcl expr operator (which includes
# () themselves) is found inside.
#
# The following types are not detected and will cause the invocation of
# the output to fail:
#    pointers of any kind
#    structures of any kind
#    unions of any kind
#    typedefs of any kind
#    arrays of any kind
#
# Useless support exists for arrays: Array element expansion by [] will
# be mapped to ().  The result then appears to be a function call, and
# the array variable never gets $ prepended to it.  An index consisting
# of a single variable name or a numeric constant will be correctly
# identified.  Indices consisting  numeric expressions are not yet
# identified.  Array initializers are not recognized.
#
# Casting of intrinsic integral and floating point types is understood.
# It is helpful if the object being cast is surrounded with ().  If not,
# () are wrapped around the first operand to the next non-unary operator.
# The unary operators are unary +, unary -, !, ~, ++ and -- (both postfix
# and prefix forms).  Casting to other types will fail.
#
# Both postfix and prefix ++ and -- are recognized and mapped to Tcl incr.
# The result of postfix operators returns the value before the increment
# by subtracting the increment from the result of incr.  Prefix forms
# incur unnecessary inefficiency by subtracting 0 from the result of incr.
# When a statement consists only of an increment expression, these
# unnecessary adjustments to both postfix and prefix forms are removed.
#
# The functions available for your use are
#     abs() acos() asin() atan() atan2() ceil()
#     cos() cosh() exp() floor() fmod() hypot()
#     log() log10() pow() rand() round() sin()
#     sinh() sqrt() srand() tan() tanh() wide()
#
# The ExprX package adds the following to that list
#     acosh() asinh() atanh() cbrt() copysign()
#     erf() erfc() exp2() expm1() fabs()
#     fdim() fma() fmax() fmin() fmod() hypot()
#     lgamma() log1p() log2() logb() nearbying()
#     nextafter() remainder() rint() tgamma()
#     trunc()
#
# You may also do casting with the int() and double() functions.
#
# Functions with side effects (such as sending output to or reading input
# from a terminal or file, e.g., printf, scanf) will not be recognized.
# Often these functions are implicitly cast to void (the return value
# is ignored).  In this case the mechanism which identifies them as
# non-keywords will comment them.


proc CtoTcl {reason statement} {
   variable TclNotC;
   variable lvalue;
   variable quotes;
   variable tclspace;
   upvar extended extended needbrace needbrace

#  local($processed, $pending, $remainder, $nextchar) = ('', '', $_[1], '');
   set processed "";
   set pending "";
   set remainder $statement;
   set nextchar "";
#  local($searchfor, $found, $resume) = ($lvalue, '', '');
   set searchfor $lvalue;
   set found "";
   set resume "";
#  local($lhs, $rhs) = ('', '');
   set rhs "";
#puts "Reason: $reason pending: \"$statement\"";
   # FIXME needbrace will be carried up to caller as side-effect
   set needbrace "";

   set prespace "";
   set postspace "";

   regexp "^($tclspace*)(.*?)\$" $remainder blagh prespace remainder;
   regexp "^(.*?)($tclspace*)\$" $remainder blagh remainder postspace;

   # Check that else did not enclose single statement in {}
   set elseclause ""
   regsub "^else$tclspace+if\\y" $remainder "elseif" remainder;
   regexp "^(else($tclspace+|\\y))(.*?)\$" $remainder blagh elseclause blagh remainder;
   # Check that return did not enclose single statement in ();
   set retclause ""
   regexp "^(return($tclspace+|\\y))(.*?)\$" $remainder blagh retclause blagh remainder;

   set nesteq 0;
   while {[regexp -indices "($searchfor)(.|\\n)" $remainder {`'} found nextchar]} {
      append pending [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found];
      set nextchar [substr $remainder $nextchar];
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end]
      if {[regexp "\[$quotes]" $found]} {
         tokenQuote "" "";
      } elseif {$found eq "="} {
         set prevchar [string index $pending end];
         append pending $found;
         if {![regexp {[<=!>]} $prevchar] && ($nextchar ne "=")} {
            set lhs([incr nesteq]) $pending;
            set pending "";
         }
      }
      set remainder $nextchar$remainder;
   }
   # End of command
   append pending $remainder;

   set rhs $pending;

   # If $nesteq == 0 and $extended == 0, 1 or 6 then this is an isolated rvalue;
   # It's either a keyword, the target of an else or return,
   # a function call with side effects, or a C declaration
   # If there is more than one word, it's not a keyword.
   # We want to ignore declarations.  We don't want to variable-munge keywords.
   # Note to users: Don't call void functions, and always assign the
   # result of the output (especially you printf() users!)
   # FIXME: should support minimal fprintf munging to Tcl puts [format ...]

#puts "nesteq: $nesteq extended: $extended elseclause: \"$elseclause\" retclause: \"$retclause\" rhs: \"$rhs\"";

   #########################################################################
   #
   #  extended:     7   6  5   4  3  2   1       0
   #                            if {expr} {?expr}?;
   #             for {expr} {expr} {expr} {?expr}?;
   #
   # nesteq != 0 ==> definitely TclExpr (have lvalue)
   # nesteq == 0 &&
   #          return ==> definitely TclExpr (return is lvalue)
   #          extended == if_2 ==> definitely TclExpr (conditional)
   #          extended == for_4 ==> definitely TclExpr (conditional)
   #          extended == for_3 ==> okay to TclExpr (should be blank)
   #          extended == for_5 ==> okay to TclExpr (should be blank)
   #         (extended == 0 ||
   #          extended == 1 ||
   #          extended == for_2 ||
   #          extended == for_6 ||
   #          else) &&
   #                  oneword ==> definitely no TclExpr (keyword)
   #                  multiword ==> definitely no TclExpr (declaration or
   #                                function call or pointless rvalue)
   #
   #  NB: We don't distinguish between if_2 and for_2; we presume if_2
   #
   #########################################################################

   set rhsneedexpr 0;
   if {$nesteq || $extended > 1 || $retclause ne "" || [regexp {\+\+|--} $rhs]} {
      foreach {rhs rhsneedexpr hascast rhs} [TclExpr "rhs" $rhs $rhsneedexpr] {break}
   }
   if {$rhsneedexpr && (!$nesteq) && ($retclause eq "")} {
      # Prefer to strip off extras for incr than to add needless expr
      while {
         [regsub "^($tclspace*)\\((-?\[01]\\+\\\[incr .*\\])\\)($tclspace*)\$" $rhs {\1\2\3} rhs]
      } {}
      regsub "^($tclspace*)-?\[01]\\+\\\[incr (.*)\\]($tclspace*)\$" $rhs {\1incr \2\3} rhs
   }

   if {$nesteq == 0} {
      if {($extended <= 1 || $extended == 6) && $retclause eq "" && [regexp {\y.+\y.+\y} $rhs] && ![regexp "^($tclspace*)incr\\y" $rhs]} {
         # Not a keyword, Comment it out.
         # (it could be an isolated rvalue, but that's kind of stupid)
         set rhs "#$rhs";                 # First line
         regsub -all {\n} $rhs "\n#" rhs; # Subsequent lines
         append rhs " \n";                # Ensure whitespace and line break to stop comment
      } elseif {[regexp {\y(elseif|if|while|for)$} $rhs keyword]} {
         set extended [expr {3 + 4 * ($keyword eq "for")}];
      }
   }

   # Final munging and serializing
   for {set j 1} {$j <= $nesteq} {incr j} {
      if {$j > 1} {append processed { [}}
      set needexpr 0;  # $needexpr better stay 0 or these aren't proper lvalues!
      regsub {=$} $lhs($j) " " lhs($j); # removing the = sign still lurking about
      # Race condition: lhs as arg will be cleared as side-effect
      foreach [list lhs($j) needexpr hascast lhs($j)] [TclExpr "lhs($j)" $lhs($j) $needexpr] {break}
      if {!$TclNotC} {regsub "^($tclspace*)\\\$" $lhs($j) {\1set } lhs($j)}
      if {[regsub "^($tclspace*)\\\[gmlayer set\\y" $lhs($j) {\1gmlayer set} lhs($j)]} {
         # Trim off ][ for parameter lvalues
         regsub "\\]($tclspace*)\$" $lhs($j) {\1} lhs($j);
         # No match here means syntax error: wasn't an lvalue
      }
      append processed $lhs($j);
   }

   if {$rhsneedexpr && ($nesteq || $retclause ne "")} {append processed "\[expr \{"}
   # To balance {} matching for vi, keep this \} here
   # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
   # KEEP THAT BACKSLASH THERE!
   append processed $rhs;
   # To balance {} matching for vi, keep this \{ here
   # STUPID TCL--DOESN'T PARSE COMMENTS DURING BRACE SCANNING.
   # KEEP THAT BACKSLASH THERE!
   if {$rhsneedexpr && ($nesteq || $retclause ne "")} {append processed "\}]"}
   append processed [string repeat {]} [incr j -2]];

   if {$retclause ne "" && $processed ne ""} {
      if {![regexp {[\s]$} $retclause]} {append retclause " "}
      # Need the result of assignment
      if {$nesteq} {set processed " \[ $processed ]"}
      set processed $retclause$processed;
   }
   if {$extended && ([incr extended -1] == 0) && ![regexp "^$tclspace*\$" $processed]} {
      # if/while/for did not enclose single statement in {}
      # Automagically understands do...while due to null statement
      # after while (expr); , previous munging of () to {} and the
      # fact that we believe statements terminate on { or } or ; or # !
      set processed " {$processed"; set needbrace "}";
   }
   if {$elseclause ne "" && $processed ne ""} {
      # else did not enclose single statement in {}
      set processed " {$processed"; set needbrace "}";
   }
   set processed $prespace$elseclause$processed$postspace;
}
#puts [info body CtoTcl]


proc TclExpr {reason expresssion alreadyneedexpr} {
   variable TclNotC;
   variable eops;
   variable mllayers;
   variable parennest;
   variable quotes;
   variable subexpr;
   variable tclspace;
   variable mathfunc;

#  local($processed, $prepending, $pending) = ('', '', '');
   set processed "";
   set prepending "";
   set pending "";
#  local($remainder, $nextchar) = ($_[1], '');
   set remainder $expresssion;
   set nextchar "";
#  local($searchfor, $found, $resume) = ($subexpr, '', '');
   set searchfor $subexpr;
   set found "";
   set resume "";
#  local($needexpr, $mlexpr, $mlaccess) = ($_[2], 0, 0);
   set needexpr $alreadyneedexpr;
   set mlexpr 0;
   set mlaccess 0;
#  local($incr, $postfix) = (0, 0);
   set incr 0;
   set postfix 0;
#  local($castpending, $mlcast) = (0, 0);
   set castpending 0;
   set mlcast 0;
#  local($closed) =  (0);
   set closed 0;

   # Life is so much easier if we guarantee one white space at the end
   # of the initial expression.  Otherwise if last char is in $searchfor,
   # we have boatloads of special cases.
   if {!$parennest} {append remainder " "}
#puts "[string repeat "   " $parennest]$parennest open: \"$remainder\"";
   while {[regexp -indices "($searchfor)(.|\\n)" $remainder {`'} found nextchar]} {
      append pending [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found];
      set nextchar [substr $remainder $nextchar];
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end]
#puts "[string repeat "   " $parennest]$parennest match: processed: \"$processed\"  prepending: \"$prepending\" pending: \"$pending\" found: \"$found\" nextchar: \"$nextchar\"";
      switch -regexp -- $found "\[$quotes]" {
         tokenQuote "" "";
      } "\[$eops]" {
         if {!($TclNotC || $incr)} {set pending [TclExprVar $pending]}
         postIncr;
         if {$castpending > 1 && $found ne "~" && ($found ne "!" || $nextchar eq "=")} {
            # Not a unary operator
            # Cast applied to single token, not parenthetical expression
            # Sneak in a closing paren and restart
            # This paren matches the opening '(' at the type portion
            # of the cast
            set remainder ")$found$nextchar$remainder";
            incr castpending -1;
            continue;
         }
         set needexpr 1;
         append prepending $pending$found;
         set pending "";
      } "\[-+]" {
         if {$nextchar eq $found} {
            # increment version
            set nextchar "";
            set needexpr 1;
            set incr [expr {$found eq "+" ? 1 : -1}];
            # Postfix version: cancel result of increment before use
            if {![regexp "^$tclspace*\$" $pending]} {set postfix [expr {-$incr}]}
            append prepending "($postfix+\[incr ";
            # To balance [] and () matching for vi, keep this ]) here
         } else {
            if {![regexp "^$tclspace*\$" $pending]} {
               # binary version
               if {!($TclNotC || $incr)} {set pending [TclExprVar $pending]}
               postIncr;
               if {$castpending > 1} {
                  # Cast applied to single token, not parenthetical expression
                  # Sneak in a closing paren and restart
                  # This paren matches the opening '(' at the type portion
                  # of the cast
                  set remainder ")$found$nextchar$remainder";
                  incr castpending -1;
                  continue;
               }
               set needexpr 1;
               append prepending $pending$found;
               set pending "";
            } else {
               # unary version
               append pending $found;
            }
         }
      } "\[Ee]" {
         if {($nextchar eq "-" || $nextchar eq "+") && [regexp {[.\d]$} $pending]} {
            # distinguish signed exponential from binary op
            append found $nextchar;
            set nextchar "";
         }
         append pending $found;
      } {[][]} {
#        if {!$TclNotC} {set found [string map {[ ( ] )} $found]}
         append pending $found;
      } {\(} {
         # To balance () matching for vi, keep this ) here
         incr parennest;
         append pending $found;
         if {!$TclNotC} {set pending [TclExprVar $pending]}
         regsub -all {\yf(abs[\s]*\()} $pending {\1} pending; # Map fabs to abs
         # To balance () matching for vi, keep this ) here
         set needexpr [expr {$needexpr || [regsub -all "\\y($mathfunc)\\s*\\(\$" $pending {\1(} pending]}];
         # To balance () matching for vi, keep this )) here
         append prepending $pending;
         set remainder $nextchar$remainder;
         set nextchar "";
         set mlexpr 0;
         foreach {remainder mlexpr mlcast pending} [TclExpr "subexp" $remainder $mlexpr] {break};
#puts "[string repeat "   " $parennest]$parennest received: pending: \"$pending\" remainder: \"$remainder\" mlexpr: $mlexpr mlcast: $mlcast"
         # Return to matched paren
         # $prepending contains the presubexpr
         # $pending contains the subexp fully munged
         # Test for cast
         if {$mlcast} {set prepending [string replace $prepending end end]}
         # Test for mlayer access
         set mlaccess 0;
         eval $mllayers;
         if {$mlaccess} {
            # Trim off trailing spaces and (
            regsub {\y(\w+)\s*\(} $prepending {[gmlayer set \1} prepending;
            regsub {\)?$} $pending "" pending; # Trim off trailing )
            if {$mlexpr} {set pending "\[expr {$pending}]"}
            append pending "]";
            append prepending $pending;
            set pending "";
         } else {
            set needexpr [expr {$needexpr || $mlexpr}];
         }
#puts "[string repeat "   " $parennest]$parennest closed: processed: \"$processed\" prepending: \"$prepending\" pending: \"$pending\"";
         append processed $prepending$pending;
         set prepending "";
         set pending "";
         incr parennest -1;
         # To balance () matching for vi, keep this ( here
      } {\)} {
         # $pending contains the innermost subexp to date.
         # It has no mlayer aggregate accesses in it.
         set remainder $nextchar$remainder;
         # Check for typecasting begin
         if {$processed eq "" && $prepending eq "" && [regexp "\\y(signed|unsigned|short|long|int|float|double)$tclspace*\$" $pending blagh type]} {
            set processed [expr {($type eq "float" || $type eq "double") ? "double" : "int"}];
            append processed "(";
            # To balance () matching for vi, keep this ) here
            set pending "";
            set castpending 1;
            set needexpr 1;
            set nextchar "";
            if {![regsub "^$tclspace*\\(" $remainder "" remainder]} {incr castpending}
            # We have now, in effect, eaten ")   (" from inside cast
            # To balance () matching for vi, keep this ) here
            # Evaluate cast in current context
            continue;
         }
         set closed 1;
         # Delay appending until out of loop; append pending $found;
         if {$parennest} {break}
         # Syntax error: too many closing parens!
         # Don't compound the problem by reapplying the extra one again!
         set nextchar "";
         append pending $found; # We can't delay the append any more.
      }
      set remainder $nextchar$remainder;
   }
   # End of subexpression.
   # No special characters
   # pertinent to this nesting level
   # should exist in $remainder now
#puts "[string repeat "   " $parennest]$parennest posting: processed: \"$processed\" prepending: \"$prepending\" pending: \"$pending\" remainder: \"$remainder\"\n[string repeat "   " $parennest]  closed: $closed incr: $incr castpending: $castpending needexpr: $needexpr";

   if {!$closed} {
      # Syntax error: too many '(' if $remainder has no ')' now!
      # (Typically, we're here because no other
      # operator characters exist in $remainder)
      set remainder [string replace $remainder end end]; # Remove the space we added
      append pending $remainder;
      set needexpr [expr {$needexpr || [regexp "\[-+$eops]\$" $remainder] > 0}]; # Is a syntax error if found
      set remainder "";
   }

   if {!($TclNotC || $incr)} {set pending [TclExprVar $pending]}
   postIncr;

   # To balance () matching for vi, keep this (( here
   # Delayed the closing paren append until here.
   if {$closed || $castpending > 1} {append pending ")"}
   if {$closed && $castpending > 1} {
#puts "Whoops: too eager!";
      # The paren just found is not for this nesting level!
      # It matches one we should have sneaked in for unparenned casts
      # Push the mismatched paren back on the queue
      set remainder ")$remainder";
   }

   # Code for the convenience of the outer caller
   if {$castpending && !$parennest} {set prepending [string replace $prepending end end]}

   set res1 $remainder;
   set res2 $needexpr;
   set res3 [expr {$castpending != 0}];
   append processed $prepending$pending;
   if {!$needexpr} {
      # Trim needless outer parens (commonly seen on return statement)
      while {[regsub "^($tclspace*)\\((.*)\\)($tclspace*)\$" $processed {\1\2\3} processed]} {};
   }
#puts "[string repeat "   " $parennest]$parennest return: \"$processed\" remainder: \"$remainder\"";
   list $res1 $res2 $res3 $processed
}
#puts [info body TclExpr]


proc postIncr {} {
   upvar incr incr pending pending postfix postfix
   if {$incr} {
      # To balance [] and () matching for vi, keep this ([ here
      append pending " $incr])";
      set postfix 0;
      set incr 0;
   }
}
#puts [info body postIncr]


proc addPendingOp {} {
   variable TclNotC;
   upvar found found needexpr needexpr pending pending prepending prepending
   set needexpr 1;
   if {!$TclNotC} {set pending [TclExprVar $pending]}
   append prepending $pending$found;
   set pending "";
}
#puts [info body addPendingOp]


proc TclExprVar {expression} {
   variable quotes;
#  local($processed, $pending) = ('', '');
   set processed "";
   set pending "";
#  local($remainder, $nextchar) = ($_[0], '');
   set remainder $expression;
   set nextchar "";
#  local($searchfor, $found, $resume) = ("\[$quotes]", '', '');
   set searchfor "\[$quotes]";
   set found "";
   set resume "";

   while {[regexp -indices "($searchfor)(.|\\n)" $remainder {`'} found nextchar]} {
      append pending [string range $remainder 0 [expr {-1 + [lindex ${`'} 0]}]];
      set found [substr $remainder $found];
      set nextchar [substr $remainder $nextchar];
      set remainder [string range $remainder [expr {1 + [lindex ${`'} 1]}] end];
      tokenQuote {TclVar;};
      append processed $pending;
      set pending "";
   }
   append pending $remainder;
   # End of string
   TclVar;
   append processed $pending;
}
#puts [info body TclExprVar]


proc TclVar {} {
   variable mlscalars;
   upvar pending pending

   # Floating point numbers of the form 123.e3 break the code
   # which looks for variable accesses: the e3 looks like a variable
   # The following strips out the unecessary decimal point.
   regsub -all {([-+]?\d+)\.([eE][-+]?\d+)} $pending {\1\2} pending;
   # Prepend $ to all variable accesses
   regsub -all {\y([_[:alpha:]]\w*\y\s*(?=([^[:space:](]|$)))} $pending {$\1} pending;
   # To balance () matching for vi, keep this ) here
   eval $mlscalars;
}
#puts [info body TclVar]

proc makeChecks {argv} {
   variable TclNotC;
   variable mllayers;
   variable mlscalars;
   variable mathfunc;

   set opeq {[-+*\/^&]};          # operators which can also assign lvalues
   set mathfunc {abs|acos|asin|atan|atan2|ceil|cos|cosh|double|exp|floor|fmod|hypot|int|log|log10|pow|rand|round|sin|sinh|sqrt|srand|tan|tanh|wide};
   # Need a catch because if package isn't present, output is written to stderr
   catch {if {[package present ExprX]} {append mathfunc {|acosh|asinh|atanh|cbrt|copysign|erf|erfc|exp2|expm1|fdim|fma|fmax|fmin|fmod|lgamma|log1p|log2|logb|nearbying|nextafter|remainder|rint|tgamma|trunc}}}

   set scalar 0;
   set vb [expr {$TclNotC ? {\y} : {\$}}]
   set itemComplete 1
   foreach {token} $argv {
      if {$token eq "-"} {
         incr scalar;
         set itemComplete 1
      } else {
         if {$itemComplete} {
            if {$scalar == 0} {
               # Create tests for aggregate variables
               append mllayers "set mlaccess \[expr {\$mlaccess || \[regexp {\\y$token\\s*\\(\$} \$prepending]}];\n"
               # To balance () matching for vi, keep this ) here
            } elseif {$scalar == 1} {
               # Create tests for scalar variables
               append mlscalars "regsub -all {$vb$token\\y} \$pending {\[gmlayer set $token]} pending;\n"
            } elseif {$scalar == 2} {
               # Create defines for scalar parameters
               append defines "   set $token \[gmlayer set $token];\n"
            }
         }
         if {$scalar < 2} {set itemComplete [expr {!$itemComplete}]}
      }
   }
#puts "mlscalars: \"$mlscalars\"";
#puts "mllayers: \"$mllayers\"";
#puts "defines: \"$defines\"";
   set defines
}
#puts [info body makeChecks]
}
# End of ::ctotcl namespace module


##############################################################################
namespace eval ::makeconstrain {
#% Call with a list consisting of options, script, objectfile, save,
#% version number, prototype, pairs of array variables and offsets,
#% a literal "-", pairs of scalar variables and offsets, a literal "-",
#% and scalar arguments from prototype.
#%
#% Options are in getopt style.  Options are:
#%   -f    script is filename to read (default)
#%   +f    script is actual script
#%
#% For the Tcl driver, additional options apply:
#%   -t    prepare a Tcl function for constraints (default)
#%   -c    prepare a C function for constraints
#%   -d    prepare a dso from the C function (default)
#%   +d    do not prepare a dso
#%   -T    script is written using Tcl expressions
#%   +T    script is written using C expressions (default)
#%
#%  If preparing a dso, additional options apply:
#%   -s    save intermediate C source code
#%   +s    delete intermediate C source code (default)
#%   -o    use IRIX o32 abi (default)
#%   -n    use IRIX n32 abi
#%

proc prepareScript {argv} {
   variable fitvars cfile mlayerid object options prototype save script scriptfile

   set abi       -o32
   set save         0
   set usefile      1
   set usedso       1
   set TclNotC      0
   set tclconstrain 1

   if {[info exists env(MAKECONSTRAIN)]} {doOpts $env(MAKECONSTRAIN)}
   set argv [lreplace $argv 0 [doOpts $argv]]

   set options   $abi;
   set cfile     /tmp/constrain[pid]
   set source    [lindex $argv 0];
   set object    [lindex $argv 1];
   set mlayerid  [lindex $argv 2];
   set prototype [lindex $argv 3];
   set fitvars   [lreplace $argv 0 3];
   lappend fitvars "-" "DELS";

   if {$usefile} {
      set scriptfile $source;
      set ScriptFile [open $source "r"];
      set script [read $ScriptFile];
      close $ScriptFile;
   } else {
      set scriptfile ""
      set script $source
   }

   if {$tclconstrain} {
      if {$save} {
         set retvalue [makeTclFile $TclNotC $script $object.tcl $fitvars]
      } else {
         set retvalue [makeTclConstrain $TclNotC $script $fitvars]
      }
   } elseif {$usedso} {
      set retvalue [makeCdso $scriptfile $script $cfile $object $options $save $mlayerid $prototype $fitvars]
   } elseif {$save} {
      set retvalue [makeCfile $scriptfile $script $object $mlayerid $prototype $fitvars]
   } else {
      set retvalue [makeCConstrain $scriptfile $script $object $mlayerid $prototype $fitvars]
   }
   set retvalue
}
#puts [info body prepareScript]


#doOpts:
# Sets flags based on options specified
proc doOpts {argv} {
   upvar tclconstrain tclconstrain
   upvar abi abi
   upvar save save
   upvar usedso usedso
   upvar usefile usefile
   upvar TclNotC TclNotC

   set ok 1
   set argc [llength $argv]
   for {set j 0} {$ok && ($j < $argc)} {incr j} {
      set arg [lindex $argv $j]
      set on [string index $arg 0]
      if {$arg eq "--"} {incr j}
      if {$arg eq "--" || ($on ne "-" && $on ne "+")} {break}
      if {$on eq "-"} {set on ""}
      set argl [string length $arg]
      for {set i 1} {$ok && ($i < $argl)} {incr i} {
         set option $on[string index $arg $i]
         switch -- $option {
            d {set usedso 1}
           +d {set usedso 0}
            f {set usefile 1}
           +f {set usefile 0}
            s {set save 1}
           +s {set save 0}
            n {set abi -n32}
            o {set abi -o32}
            t {set tclconstrain 1}
            c {set tclconstrain 0}
            T {set TclNotC 1}
           +T {set TclNotC 0}
            default {set ok 0}
         }
      }
   }
   incr j -1
}
#puts [info body doOpts]


# Generates DSO constrain.so to implement constraints for mlayer-type
# programs.  Given a suitable script, it creates a C file on the fly with
# proper mappings of mlayer variables and creates the shared object.

# The intermediate cfile.c is deleted if save is not 1.
# The intermediate cfile.o is always deleted.

proc makeCdso {scriptfile script cfile object options save mlayerid prototype fitvars} {

   makeCfile $scriptfile $script $cfile.c $mlayerid $prototype $fitvars

   # Programs we use
   set SH /bin/sh
   set CC /usr/bin/cc
   set LD /usr/bin/ld

   # -woff 84 ignores warning about not using libm if user doesn't call math funcs

   set compile "\
      $CC $options -g -o $cfile.o -c $cfile.c && \
      $LD $options -o $object -shared -B symbolic -check_registry /usr/lib/so_locations -exported_symbol mlayerid,constrain $cfile.o -woff 84 -delay_load -lm"
   set retvalue 0
   if {[catch {exec $SH -c $compile} output]} {
      global errorInfo errorCode;
      set savedInfo $errorInfo;
      if {[lindex $errorCode 0] ne "CHILDSTATUS"} {
         $error $output $savedinfo
      } else {
         puts stderr $output;
         set retvalue [lindex $errorCode 2];
      }
   }
   catch {file delete -force $cfile.o}
   if {$save != 1} {catch {file delete -force $cfile.c}}
   set retvalue
}
#puts [info body makeCdso]


proc makeCfile {scriptfile script cfile mlayerid prototype fitvars} {
   set cFile [open $cfile "w"]
   puts $cFile [makeCConstrain $scriptfile $script $cfile $mlayerid $prototype $fitvars]
   close $cFile
}
#puts [info body makeCfile]


#makeCConstrain:
# Converts the syntax of the script into C syntax
proc makeCConstrain {scriptfile script cfile mlayerid prototype fitvars} {

   if {$prototype ne ""} {set prototype ", $prototype"};
   set prototype "int DELS, double _a\[]$prototype";

   set constrain "#include <math.h>
#define extern

char *SCCS_VERSION = \"@(#) $cfile\[$scriptfile\]	Constraints for mlayer-type progs ($mlayerid)\";
long int mlayerid = $mlayerid;

void constrain($prototype)
{\n";

   #defines for the variables
   append constrain [::decase::makeCDefs $fitvars];
   # So cc gives user correct line number for errors
   append constrain "\n#line 1 \"$scriptfile\"\n";

   append constrain [::decase::script2C $script];

   append constrain "}";
}
#puts [info body makeCConstrain]


proc makeTclFile {TclNotC script cfile fitvars} {
   set cFile [open $cfile "w"]
   puts $cFile [makeTclConstrain $TclNotC $script $fitvars]
   close $cFile;
}
#puts [info body makeTclFile]


proc makeTclConstrain {TclNotC script fitvars} {

   # set  constrain "proc constrain {} \{\n"
   set    constrain ""
   append constrain {   if {[llength [info procs do]]} {rename do tclconstraindo}
   proc do {body while condition} {uplevel $body; while {[uplevel expr $condition]} {uplevel $body}}
   set M_E             2.7182818284590452354
   set M_LOG2E         1.4426950408889634074
   set M_LOG10E        0.43429448190325182765
   set M_LN2           0.69314718055994530942
   set M_LN10          2.30258509299404568402
   set M_PI            3.14159265358979323846
   set M_PI_2          1.57079632679489661923
   set M_PI_4          0.78539816339744830962
   set M_1_PI          0.31830988618379067154
   set M_2_PI          0.63661977236758134308
   set M_2_SQRTPI      1.12837916709551257390
   set M_SQRT2         1.41421356237309504880
   set M_SQRT1_2       0.70710678118654752440
   set MAXFLOAT        3.40282346638528860e+38
};

   set ::ctopretcl::TclNotC $TclNotC
   set ::ctotcl::TclNotC    $TclNotC

   ::decase::makeCDefs $fitvars
   set script [::decase::script2C $script]

   ::ctopretcl::makePreChecks $fitvars
   set script [::ctopretcl::CtoPreTcl $script]

   # sets for invariable parameters
   append constrain [::ctotcl::makeChecks $fitvars]
   append constrain [::ctotcl::PreTcltoTcl $script]

   append constrain {   rename do "";
   if {[llength [info procs tclconstraindo]]} {rename tclconstraindo do}};
#  append constrain "\n\}";
}
#puts [info body makeTclConstrain]
}
# end of ::makeconstrain namespace module


#TCL MAIN BEGINS
if {[info script] eq "$::argv0"} {
  ::makeconstrain::prepareScript $argv
}

