/***********************************************************************************************
**  Program Name:      autoexec.sas
**  Programmer:        tsunsian
**  Date:              15-APR-2021
**  Project/Study:     
**  Purpose:           Set up programming environment
**/

%* program path; 
%let progpath=%sysfunc(ifc("%sysfunc(getoption(sysIn))" ne "", %sysfunc(getoption(sysIn)), %nrstr(&_sasprogramfile.)));

%* program name;
%let progname=%scan(&progpath.,-1,%str(/));

%* current working direcotry; 
%let cwd=%sysfunc(prxchange(s#(/gbs/[a-z0-9/-]+)/[^/]+#$1#, -1, &progpath.)); 

%* study directory; 
%let studydir=%sysfunc(prxchange(s#(/gbs/(dev|prod)/clin/programs/[a-z]{2}/\d{3}/\d{3})/.*#$1#,-1,&cwd.)); 
%* protocol number; 
%let protocol=%upcase(%sysfunc(prxchange(s#[a-z/]+/([a-z]{2})/(\d{3})/(\d{3})#$1$2$3#,-1,&studydir.)));
%* analysis name; 
%let analysis=%sysfunc(prxchange(s#&studydir./([\w-]+)/.*#$1#,-1,&cwd.));
%* program folder name; 
%let progfolder=%sysfunc(prxchange(s#&studydir./&analysis./([\w-/]+)#$1#,-1,&cwd.));

%* status of deliverable; 
%macro status;
%global status;
%if %index(%bquote(&progpath.),%str(/gbs/dev/)) %then %let status=DRAFT; 
%else %if %index(%bquote(&progpath.),%str(/gbs/prod/)) %then %let status=FINAL; 
%mend status;
%status;

%* output files; 
%let outputdir=&cwd./output; 

%* Data source;
libname adam "" access=readonly; 


%let orientation=landscape;
%let ps=48;
%let ls=132;

ods escapechar="!"; 
options missing='' center nodate nonumber nobyline label msglevel=I compress=NO nosymbolgen mprint nomlogic;
options validvarname=v7 ps=&ps. ls=&ls. orientation=&orientation. papersize=letter formchar="|----|+|---+=|-/\<>*";
options sasautos=("&cwd", "&studydir./&analysis/macro/", "&studydir./library/macro/", sasautos); 
options fmtsearch=(work) cmplib=(work.functions);

%put NOTE: &=progpath;
%put NOTE: &=progname; 
%put NOTE: &=cwd;
%put NOTE: &=studydir;
%put NOTE: &=protocol; 
%put NOTE: &=analysis; 
%put NOTE: &=progfolder; 
%put NOTE: &=outputdir;


%* formats; 
proc format lib=work; 
  picture pct (default=8 round fuzz=0)
    0             = ' ' 
    0< - <0.1     = ' ( <0.1)' (noedit)
    0.1 - <9.95   = '9.9)' (mult=10 prefix=' (  ')
    9.95 - <99.95 = '99.9)' (mult=10 prefix=' ( ')
    99.95 - 100   = '999.9)' (mult=10 prefix=' (')
    other         = ' '
    ;
  picture pval (fuzz=0 round)
    0 - <0.00015       = '<0.0001' (noedit)
    0.00015 - <0.99995 = '9.9999'
    0.99995 - high     = '>0.9999' (noedit)
    other              = ' '
    ;
run;


%* functions;
proc fcmp outlib=work.functions.fun; 
  * function to calculate --DY; 
  function computedy(dtc $, rfdtc $); 
    if cmiss(rfdtc,dtc)=0 and prxmatch('/^\d{4}-\d\d-\d\d[T:\d-]*$/',cats(dtc)) then do; 
      x=input(prxchange('s/^(\d{4}-\d\d-\d\d)[T:\d-]*$/$1/',-1, cats(dtc)),e8601da.) - input(rfdtc,e8601da.) + 
        (input(prxchange('s/^(\d{4}-\d\d-\d\d)[T:\d-]*$/$1/',-1, cats(dtc)),e8601da.) >= input(rfdtc,e8601da.));
    end; 
    return(x); 
  endsub;
run;

