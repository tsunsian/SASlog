/***************************************************************************************
**     Program Name:        checkunik.sas
**     Programmer:          tsunsian
**     Date:                06-Apr-2021
**
**     Purpose:             Check uniqueness of records in a dataset
**     Parameters:          inds=    (required) Input dataset; 
**                          bykeys=  (optional) Key variables against which uniqueness is checked, 
**                                     if omitted, all variables in &inds are used; 
**                          outds=   (optional) Output dataset to hold non-unique records for manual check, 
**                                     default to _&inds_non_unique; 
**                          whercl=  (optional) Where clause to subset the input dataset in case of need; 
**                          msgtype= (optional) Message to print to log, values are (n)ote, (w)arning, (e)rror, 
**                                     default to (n)ote; 
**/   


%macro checkunik(inds=, bykeys=, outds=_%sysfunc(tranwrd(&inds.,.,_))_non_unique, whercl=1, msgtype=n);

%* validate parameters; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 
%if "&outds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Output data set is not specified. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(prxmatch(/^(n(ote)?|w(arning)?|e(rror)?)$/i,%bquote(&msgtype.))) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Valid values to MSGTYPE are n(ote), w(arning), e(rror), case-insensitive. Macro will terminate.; 
  %abort; 
%end;

%* tidy parameters; 
%local lc_bykeys lc_lstvar lc_msg1 lc_msg2;
%if "&bykeys"="" %then %do; 
  proc sql noprint; 
    select name into :lc_bykeys separated by ' '
    from dictionary.columns
    where libname="%upcase(%sysfunc(ifc(%index(&inds,.), %scan(&inds,1,.), WORK)))" and 
           memname="%upcase(%sysfunc(ifc(%index(&inds,.), %scan(&inds,2,.), &inds)))"
    order by varnum;
  quit; 
%end; 
%else %let lc_bykeys=%cmpres(&bykeys.); 
%let lstvar=%scan(&lc_bykeys.,-1,%str( )); 

%if "%upcase(%substr(&msgtype.,1,1))" eq "N" %then %do; 
  %let lc_msg1=NO; 
  %let lc_msg2=TE:[QC]; 
%end; 
%else %if "%upcase(%substr(&msgtype.,1,1))" eq "W" %then %do; 
  %let lc_msg1=WAR; 
  %let lc_msg2=NING:[QC]; 
%end; 
%else %if "%upcase(%substr(&msgtype.,1,1))" eq "E" %then %do; 
  %let lc_msg1=ER; 
  %let lc_msg2=ROR:[QC]; 
%end; 

%* check uniqueness; 
proc sort data=&inds. out=__temp__; 
  by &lc_bykeys.; 
  where &whercl.; 
run;

data &outds.; 
  set __temp__ end=eof; 
  by &lc_bykeys.;
  retain num_nonunique 0; 
  if not (first.&lstvar. and last.&lstvar.) then do; 
    output;
    num_nonunique + 1; 
  end; 
  if eof then do; 
    if num_nonunique>0 then put "&lc_msg1." "&lc_msg2 " num_nonunique "duplicates detected. Check &outds. for detail.";
    else put 'NOTE:[QC] No duplicates are detected.';
    call symputx('lc_num',num_nonunique); 
  end; 
run;


%* delete temporary data sets; 
proc sql; 
  drop table __temp__ %if &lc_num.=0 %then ,&outds.;;
quit;
    
%mend checkunik; 

