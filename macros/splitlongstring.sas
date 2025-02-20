/***************************************************************************************
**     Program Name:        splitlongstring.sas
**     Programmer:          tsunsian
**     Date:                27-Apr-2021
**
**     Purpose:             Split long strings between words (without breaking any words)
**                          
**     Parameters:          string           (required) Text string to be split; 
**                          substringLen=    (optional) Max length at which splitting is forced, 
**                                             default to the value of the LINESIZE system option; 
**                          splitByChar=     (optional) Delimiter of words, default to a single space; 
**                          returnDelimiter= (optional) Delimiter to concatenate the substrings, default to @; 
**     
***/
%macro splitlongstring(string, splitByChar=%str( ), substringLen=%sysfunc(getoption(LS)), returnDelimiter=@); 

%local str str0 leftover rtn pos chr delim;

%let str=%qsysfunc(compbl(%superq(string)));
%let chr=%superq(splitByChar); 
%let delim=%superq(returnDelimiter); 
%let rtn=;

%let leftover=&str.;
%do %while(%length(&leftover.)>&substringLen.); 

  %let str0=&leftover.;  
  %do %while(%length(%superq(str0))+%length(%unquote(&chr.)) > &substringLen.);  
    %let pos=%sysfunc(find(&str0.,&chr.,-%length(&str0.)));
    %if &pos.>0 %then %let str0=%qsubstr(&str0.,1,%eval(&pos.-1));
    %else %do; 
      %put %str(W)ARNING: The length of at least one word in "&str0." is greater than &substringLen..; 
      %let rtn=&rtn.%sysfunc(ifc(%length(%unquote(&chr.)) and %length(&rtn.),&chr.,))%sysfunc(ifc(%length(&rtn.),&delim.,))&leftover.;
      %goto exit; 
    %end; 
  %end; 
  
  %let rtn=&rtn.%sysfunc(ifc(%length(%unquote(&chr.)) and %length(&rtn.),&chr.,))%sysfunc(ifc(%length(&rtn.),&delim.,))&str0.; 
  %let leftover=%qsubstr(&leftover.,%eval(&pos.+%sysfunc(lengthc(&chr.)))); 
%end;

%let rtn=&rtn.%sysfunc(ifc(%length(%unquote(&chr.)) and %length(&rtn.),&chr.,))%sysfunc(ifc(%length(&rtn.),&delim.,))&leftover.;
   
%exit: 

%superq(rtn)

%mend splitlongstring; 
