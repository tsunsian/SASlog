/***************************************************************************************
**     Program Name:        not_in_acrf.sas
**     Programmer:          tsunsian
**     Date:                03-Aug-2021
**
**     Purpose:             Pull together a list of SDTM variables not annotated on the aCRF
**                          
**     Parameters:          xfdf=    (required) fileref or physical path of .xfdf file; 
**                          sdtmlib= (required) SDTM libref; 
**                          debug=   (optional) defaulted to N; 
**/    



%macro not_in_acrf(xfdf="acrf.xfdf", sdtmlib=sdtm, debug=N); 

%local supplist i;

%if %sysfunc(libref(%superq(sdtmlib))) %then %do; 
  %put %str(E)RROR: [&sysmacroname] LIBREF %upcase(&sdtmlib.) has not been assigned. Macro will terminate.; 
  %abort;
%end; 


%** extract annotations; 
data _anno; 
  infile &xfdf. length=len; 
  input line $varying1000. len;
  length anno rect $200; 
  retain page keep anno rect regex1-regex3;
  if _n_=1 then do; 
    regex1=prxparse('/\bpage="(\d+)"/'); 
    regex2=prxparse('/\brect="([0-9.,]+)"/');
    regex3=prxparse('/^>(.+)<\/(p|span)$/'); 
  end;

  if prxmatch('/<freetext/',line) then keep=1; 
  if keep=1 then do; 
    if prxmatch(regex1,line) then page=input(prxposn(regex1,1,line),??best.)+1;
    if prxmatch(regex2,line) then rect=prxposn(regex2,1,line);
    if prxmatch(regex3,cats(line)) then anno=prxposn(regex3,1,cats(line));
  end; 
  if prxmatch('/<\/freetext/',line) then do; 
    keep=0; 
    if not missing(anno) then output; 
    call missing(anno,page,rect);
  end;
run;


%** get all variables in SDTM, including SUPP; 
proc sql; 
  create table _sdtmvars as
  select memname, name
  from dictionary.columns
  where libname="%upcase(&sdtmlib)" and prxmatch('/DOMAIN|[A-Z]{2}SEQ|STUDYID|USUBJID|[A-Z]{2}BLFL|EPOCH/',name)=0 and 
    prxmatch('/^SUPP[A-Z]+|TS/',memname)=0; 
quit;

%* get any QNAMs; 
proc sql noprint; 
  select memname into :supplist separated by ' '
  from dictionary.tables
  where libname="%upcase(&sdtmlib)" and prxmatch('/^SUPP[A-Z]+/',memname);
quit;

data _suppqnams;
  set _null_; 
run;

%if &supplist. ne %then %do;

data _null_;
  if 0 then set _sdtmvars(keep=memname); 
  length name qnam $8 qorig $50;
  dcl hash x(ordered:'a');
  x.definekey('memname','name');
  x.definedone(); 

%let i=1; 
%do %while(%scan(&supplist.,&i.,%str( )) ne );  
  dcl hash h&i.(dataset: "&sdtmlib..%scan(&supplist.,&i.,%str( ))");
  dcl hiter i&i.("h&i."); 
  h&i..definekey('qnam','qorig');
  h&i..definedone(); 

  memname="%scan(&supplist.,&i.,%str( ))"; 
  do while(i&i..next() eq 0); 
    name=qnam; 
    if prxmatch('/crf/i',qorig) then x.add();
  end; 
  
  h&i..delete();
  i&i..delete();
  
  %let i=%eval(&i.+1);
%end;

  x.output(dataset:"work._suppqnams");
  stop; 
run;

%end; 

data _sdtmvars; 
  set _sdtmvars _suppqnams;
run;


%** Compare the SDTM database with aCRF;
data _vars_not_in_acrf; 
  if _n_=1 then do; 
    if 0 then set _anno(keep=anno); 
    dcl hash h(dataset:'_anno',ordered:'y');
    dcl hiter hi('h'); 
    h.definekey('anno');
    h.definedone(); 
  end; 
  set _sdtmvars;
  found=0; 
  do while(hi.next()=0); 
    if index(anno,cats(name)) then do; 
      found=1;
      leave;
    end; 
  end;
  rc=hi.first(); 
  if found=0; 
  drop anno rc; 
run;


%* delete intermediate datasets;
%if &debug.=N %then %do; 
  proc datasets lib=work memtype=data nolist; 
    delete _anno _sdtmvars _suppqnams;
  quit; 
%end; 

%mend not_in_acrf; 
