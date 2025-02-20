/***************************************************************************************
**     Program Name:        epoch.sas
**     Programmer:          tsunsian
**     Date:                12-Oct-2021
**
**     Purpose:             Populate the EPOCH and TAETORD variables from SDTM.SE
**     Parameters:          inds=   (required) Input dataset; 
**                          outds=  (required) Output dataset, default to &inds; 
**                          dtc=    (required) The --DTC variable in ISO 8601 format, used to determine EPOCH; 
**                          se_lib= (required) The libref to the library where SDTM.SE resides, default to LEVEL1; 
**                          domain= (optional) Domain being processed; 
**                          debug=  (optional) debugging option, default to N;
**/     



%macro epoch(inds=, outds=&inds., dtc=, se_lib=level1, domain=, debug=N); 

%* validate parameters; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 

%if %sysfunc(libref(&se_lib.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Library %upcase(&se_lib) has not been assigned. Macro will terminate.; 
  %abort;
%end; 

%local lc_lib lc_mem dtc_ext se_ext;
%if %index(&inds.,.) %then %do; 
  %let lc_lib=%upcase(%scan(&inds.,1,.));
  %let lc_mem=%upcase(%scan(&inds.,2,.));
%end;
%else %do; 
  %let lc_lib=WORK;
  %let lc_mem=%upcase(&inds.);
%end;
proc sql noprint; 
  select count(1) into :dtc_ext trimmed
  from dictionary.columns
  where libname="&lc_lib" and memname="&lc_mem" and upcase(name)="%upcase(&dtc)" and type='char';
  
  select count(1) into :se_ext trimmed
  from dictionary.tables
  where libname="%upcase(&se_lib)" and memname="SE";
quit;
%if (not &dtc_ext.) %then %do; 
  %put %str(E)RROR: [&sysmacroname] %upcase(&dtc.) does not exist in %upcase(&inds.). Macro will terminate.; 
  %abort; 
%end;
%if (not &se_ext.) %then %do; 
  %put %str(E)RROR: [&sysmacroname] %upcase(&se_lib..SE) does not exist. Macro will terminate.; 
  %abort; 
%end;


%* create epoch; 
%local varlist;
proc sql noprint; 
  select name into :varlist separated by ' '
  from dictionary.columns
  where libname="&lc_lib" and memname="&lc_mem" and upcase(name) not in ("TAETORD" "EPOCH");
quit;

proc sort data=&se_lib..se out=_sdtm_se(rename=(epoch=_epoch taetord=_taetord sestdtc=_sestdtc)); 
  by usubjid descending sestdtc;
run;

data &outds.; 
  retain &varlist.;
  attrib TAETORD length=8 label='Planned Order of Element within Arm';
  attrib EPOCH length=$200 label='Epoch';
  if _n_=1 then do; 
    if 0 then set _sdtm_se(keep=_sestdtc _epoch _taetord);
    dcl hash h(dataset:"_sdtm_se", multidata:"y");
    h.definekey('usubjid');
    h.definedata('_sestdtc','_epoch','_taetord');
    h.definedone();
  end;   
  set &inds.;
  call missing(epoch,taetord);
  length _dtc_tmp $19; 
  if prxmatch('/^\d{4}-\d\d-\d\d(T\d\d:\d\d)?(:\d\d)?$/',cats(&dtc.)) then _dtc_tmp=cats(&dtc.);
  else if prxmatch('/^\d{4}(-\d\d)*[T:-\d]*/',left(&dtc.)) then _dtc_tmp=prxchange('s/^(\d{4}(-\d\d)*)[T:-\d]*/$1/',-1,left(&dtc.));
  
  if not missing(_dtc_tmp) then do rc=h.find() by 0 while(rc=0);
    if substrn(_dtc_tmp,1,min(lengthn(_dtc_tmp),lengthn(_sestdtc))) > substrn(_sestdtc,1,min(lengthn(_dtc_tmp),lengthn(_sestdtc))) > '' or (
        length(_dtc_tmp)>=10 and 
          substrn(_dtc_tmp,1,min(lengthn(_dtc_tmp),lengthn(_sestdtc))) = substrn(_sestdtc,1,min(lengthn(_dtc_tmp),lengthn(_sestdtc))) 
      ) then do; 
      epoch=_epoch;
      taetord=_taetord;
      leave;
    end;         
    rc=h.find_next(); 
  end;
  
  %if %upcase(&domain.)=DS %then %do; 
    if dscat='PROTOCOL MILESTONE' then call missing(epoch, taetord);
  %end; 
  %if %upcase(&debug.)=N %then %do;
    drop _sestdtc _epoch _taetord _dtc_tmp rc; 
  %end; 
run;


%* delete intermediate datasets;
%if %upcase(&debug.)=N %then %do; 
  proc datasets lib=work memtype=data nolist; 
    delete _sdtm_se;
  quit; 
%end; 


%mend epoch;



