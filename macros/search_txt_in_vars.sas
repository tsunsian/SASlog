/***************************************************************************************
**     Program Name:        search_txt_in_vars.sas
**     Programmer:          tsunsian
**     Date:                01-Jun-2021
**
**     Purpose:             Search a textual value or pattern in variables, e.g. PARAMCD, across the database
**     Parameters:          inlib= (required) Libname; 
**                          vars=  (required) List of variables to search through, space-delimited; 
**                          value= (required) Value to be searching for. Backward slash invalid, regex allowed;  
**                          case=  (optional) Case-sensitive or not: y or n, default is case-insensitive; 
**                          whole= (optional) Whole word only: y or n, default is no; 
**                          debug= (optional) default is n; 
**     
*****/


%macro search_txt_in_vars(inlib=, vars=, value=, case=n, whole=n, debug=N)/ minoperator;

%* validate parameters; 
%if %sysfunc(libref(&inlib.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Libref &inlib. has not been assigned. Macro will terminate.; 
  %abort; 
%end;
%if not (%upcase(&case.) in Y N) %then %do;
  %put %str(E)RROR: [&sysmacroname] Valid values to %nrstr(&CASE) are Y or N. Macro will terminate.; 
  %abort; 
%end;  
%if not (%upcase(&whole.) in Y N) %then %do;
  %put %str(E)RROR: [&sysmacroname] Valid values to %nrstr(&WHOLE) are Y or N. Macro will terminate.; 
  %abort; 
%end;  

%local lc_vars lc_case lc_whole; 
%let lc_vars=%sysfunc(tranwrd(%cmpres(&vars.),%str( ),|));
%let lc_case=; 
%if %upcase(&case.)=N %then %let lc_case=i; 
%let lc_whole=;
%if %upcase(&whole.)=Y %then %let lc_whole=\b; 

proc sql;
  create table _vars_found as 
  select libname as lib_name, memname as ds_name, name as var_name, type, length
  from dictionary.columns
  where libname="%upcase(&inlib)" and prxmatch(%sysfunc(quote(/^(%superq(lc_vars))$/i)),cats(name))
  order by var_name, length desc, ds_name;
quit;

%if &sqlobs.=0 %then %do; 
  %put %str(W)ARNING: [&sysmacroname] Variables &vars. are not found in any of the datasets. Macro will terminate.; 
  %return; 
%end;
%else %if &sqlobs.>0 %then %do;

  %local i count maxl; 
  %do i=1 %to &sqlobs.;
    %local ds&i. var&i.; 
  %end; 
  data _null_; 
    set _vars_found end=eof; 
    retain maxl ;
    call symputx(cats('ds',_n_),ds_name);
    call symputx(cats('var',_n_),var_name);
    maxl=max(maxl,length);
    if eof then do; 
      call symputx('count',_n_);
      call symputx('maxl',maxl);
    end; 
  run;
  
  data _null_;
    length value_detected $&maxl.; 
    if 0 then set _vars_found; 
    dcl hash h(ordered: 'y');
    h.definekey('lib_name','ds_name','var_name','value_detected');
    h.definedone(); 
    dcl hash hx; 
    dcl hiter hi; 
  %do i=1 %to &count.;
    if 0 then set &inlib..&&ds&i.(keep=&&var&i.);
    hx=_new_ hash(dataset: "&inlib..&&ds&i.(keep=&&var&i.)");
    hi=_new_ hiter("hx");
    hx.definekey("&&var&i."); 
    hx.definedone();
    
    lib_name="%upcase(&inlib)";
    ds_name="&&ds&i";
    var_name="&&var&i";
    do while(hi.next() eq 0);
      value_detected=cats(&&var&i.);
      if prxmatch(%sysfunc(quote(/&lc_whole.%superq(value)&lc_whole./&lc_case.)),value_detected) then do; 
        rc=h.check();
        if rc then rc=h.add();
      end; 
    end; 
  %end; 
    count=h.num_items;
    if count=0 then put 'WAR' 'NING:[QC]' " [&sysmacroname] %bquote(&value) is not found in any of the datasets. ";
    else do; 
      h.output(dataset: 'work._search_txt_in_vars_results'); 
      put 'WAR' 'NING:[QC]' " [&sysmacroname] " count "unique occurrences of %bquote(&value) are found. Check WORK._SEARCH_TXT_IN_VARS_RESULTS for details.";
    end; 
    stop; 
  run;
  
%end; 

%* delete temporary data sets; 
%if &debug. eq N %then %do;
proc sql; 
  drop table _vars_found;
quit;
%end; 

%mend search_txt_in_vars; 

