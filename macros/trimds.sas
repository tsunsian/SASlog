/***************************************************************************************
**     Program Name:        trimds.sas
**     Programmer:          tsunsian
**     Date:                01-Oct-2021
**
**     Purpose:             Trim character (SDTM or ADaM) variables based on maximum length; 
**     Parameters:          inds=  (required) Input dataset; 
**                          outds= (optional) Output dataset, default to &inds;
**                          debug= (optional) Debug option; 
**     
***/


%macro trimds(inds=, outds=&inds., debug=N); 

%local loclib locmem dslabel charvarlist;

%* validate parameters; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 
%else %do;
  %if %index(&inds.,.) %then %do; 
    %let loclib=%scan(%upcase(&inds.),1,.);
    %let locmem=%scan(%upcase(&inds.),2,.);
  %end;
  %else %do; 
    %let loclib=WORK;
    %let locmem=%upcase(&inds.);
  %end; 
%end; 


%* retain dataset label if any;
proc sql noprint; 
  select memlabel into :dslabel trimmed
  from dictionary.tables
  where libname="&loclib" and memname="&locmem" and memtype='DATA';
quit;


%* list of character variables to be processed;
proc sql noprint; 
  select name into :charvarlist separated by ' '
  from dictionary.columns
  where libname="&loclib" and memname="&locmem" and type='char' and memtype='DATA';
quit;

%if "&charvarlist"="" %then %do;
  %put NOTE: [&sysmacroname] %upcase(&inds.) doesn%str(%')t contain any character variables. No trimming is necessary.;
  %return;
%end; 


%* obtain max length for character varaibles;
%local i ntotl;
data _null_; 
  call symputx('ntotl',ntotl);
  stop;
  set &inds. nobs=ntotl;
run;

%if &ntotl.>0 %then %do; 
  %let i=1;
  proc sql;
    create table _max_l as
    select 
    %do %while(%scan(&charvarlist.,&i.,%str( )) ne);
      max(length(%scan(&charvarlist.,&i.,%str( )))) as %scan(&charvarlist.,&i.,%str( )) 
      %if %eval(&i. < %sysfunc(countw(&charvarlist.,%str( )))) %then ,;
      %let i=%eval(&i.+1);
    %end; 
    from &inds.;
  quit;
%end; 


%* update attributes with new lengths;
data _max_l_2;
  set sashelp.vcolumn;
  where libname="&loclib" and memname="&locmem" and memtype='DATA';
%if &ntotl.>0 %then %do; 
  if _n_=1 then set _max_l;
  %let i=1; 
  %do %while(%scan(&charvarlist.,&i.,%str( )) ne);
    if name="%scan(&charvarlist.,&i.,%str( ))" then length=%scan(&charvarlist.,&i.,%str( ));
    %let i=%eval(&i.+1);
  %end; 
%end;
%else %do;
  if type='char' then length=1;
%end; 
run;

%local loc_attrs;
proc sql noprint; 
  select catx(' ', name, 'label="'||cats(label)||'"', cats('length=',ifc(type='char','$',''),length)) 
     into :loc_attrs separated by ' '
  from _max_l_2;
quit;


%* update &inds;
data &outds.(label="&dslabel"); 
  attrib &loc_attrs.;
%if &ntotl.=0 %then %do; 
  call missing(of _all_);
  stop;
%end;
%else %do; 
  set &inds.( rename=(
      %let i=1;
      %do %while(%scan(&charvarlist.,&i.,%str( )) ne);
        %scan(&charvarlist.,&i.,%str( ))=_%scan(&charvarlist.,&i.,%str( ))
        %let i=%eval(&i.+1);
      %end; 
    ));
    %let i=1;
    %do %while(%scan(&charvarlist.,&i.,%str( )) ne);
      %scan(&charvarlist.,&i.,%str( ))=_%scan(&charvarlist.,&i.,%str( ));
      drop _%scan(&charvarlist.,&i.,%str( ));
      %let i=%eval(&i.+1);
    %end; 
%end;
run;


%* debugging; 
%if &debug.=N %then %do; 
  proc datasets lib=work memtype=data nolist; 
    delete _max_l _max_l_2;
  quit; 
%end;

%mend trimds;
