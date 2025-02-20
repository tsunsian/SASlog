/***************************************************************************************
**     Program Name:        justify.sas
**     Programmer:          tsunsian
**     Date:                22-Apr-2021
**
**     Purpose:             Justify (left, right or center) a single string, or evenly space multiple strings
**                          
**     Parameters:          strings    (required) String(s) to be justified or evenly spaced; 
**                          delimiter= (optional) Separator for multiple strings, default is @;  
**                          linesize=  (optional) Total line size available, default to the value of
**                                        the LINESIZE system option; 
**                          just=      (optional) Justification when a single string is provided, 
**                                         valid values are L, R or C, default to L; 
**/     



%macro justify(strings, delimiter=@, linesize=%sysfunc(getoption(LS)), just=l) / minoperator; 

%* if more than one string is specified, the return value is all strings evenly spaced; 
%* if only one string is specified, the return value is a left or right justified - working with the CENTER option; 

  %local nstr lenStr returnVal space_tot i; 
  %let nStr=%sysfunc(countw(%superq(strings),%superq(delimiter))); 
  
  %do i=1 %to &nStr.;
    %let str_&i=%qscan(%superq(strings),&i.,%superq(delimiter)); 
    %let lenStr=%eval(&lenStr.+%length(&&str_&i.)); 
  %end; 
  %put NOTE: [&sysmacroname] &=lenStr;
  %if &lenStr.>%eval(&linesize.-&nStr.+1) %then %do; 
    %put %str(W)ARNING: [&sysmacroname] The total length of strings are > %nrstr(&linesize). No justification is performed. ;
    %put %str(W)ARNING: [&sysmacroname] The string is: &strings..; 
    %return; 
  %end; 
  
  %let space_tot=%eval(&linesize.-&lenStr.);
  
  %* left or right justify a single string; 
  %local space_up;
  %if &nStr.=1 %then %do; 
    %if not (%upcase(&just.) in L R C) %then %do; 
      %put %str(ERR)OR: [&sysmacroname] The only valid values for %nrstr(&just) are L, R or C. Macro will be terminated. ;
      %abort return; 
    %end; 
    %if &space_tot.>0 %then %do; 
      %if %upcase(&just.)=L %then %let returnVal=&str_1.%qsysfunc(repeat(%str( ),%eval(&space_tot.-1))); 
      %if %upcase(&just.)=R %then %let returnVal=%qsysfunc(repeat(%str( ),%eval(&space_tot.-1)))&str_1.; 
      %if %upcase(&just.)=C %then %do; 
        %let space_up=%sysfunc(ceil(&space_tot./2));
        %if &space_tot.=1 %then %let returnVal=&str_1.%qsysfunc(repeat(%str( ),&space_up.-1));
        %else %let returnVal=%qsysfunc(repeat(%str( ),&space_tot.-&space_up.-1))&str_1.%qsysfunc(repeat(%str( ),&space_up.-1));
      %end;
    %end; 
    %else %let returnval=&str_1.; 
  %end; 
  
  %* evenly space multiple strings;
  %local space_sep space_extra; 
  %if &nStr.>1 %then %do; 
    %let space_sep=%sysfunc(floor(&space_tot./(&nStr.-1))); 
    %let space_extra=%eval(&space_tot.-&space_sep.*(&nStr.-1)); 
    %put &=space_tot &=space_sep &=space_extra;
    %do i=1 %to &nStr.; 
      %if &i.<&nStr. %then %let returnVal=&returnval.&&str_&i.%qsysfunc(repeat(%str( ),%eval(&space_sep.-1))); 
      %else %let returnVal=&returnval.&&str_&i.; 
      %if &space_extra.>0 %then %do; 
        %let returnVal=&returnVal.%str( ); 
        %let space_extra=%eval(&space_extra.-1); 
      %end; 
    %end; 
  %end; 
  
  &returnVal.

%mend justify; 


  
