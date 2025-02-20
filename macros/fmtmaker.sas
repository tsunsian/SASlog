
%* macro to create formats and informats from dataset; 

%macro fmtmaker(inds=, fmtname=, type=c, start=, label=, altlabel=%str( ), whercl=1); 

%* validate parameters; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 
%if not %sysfunc(prxmatch(/^[cnij]$/i,%bquote(&type.))) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Valid values to TYPE are c, n, i, or j, case-insensitive. Macro will terminate.; 
  %abort; 
%end;


%* create the input control data set; 
proc sql; 
  create table cntlin as 
  select distinct cats(&start.) as start, calculated start as end, cats(&label.) as label, "&fmtname" as fmtname, "&type" as type
  from &inds.
  where &whercl.;
quit; 

data cntlin; 
  set cntlin end=eof; 
  output; 
  if eof then do; 
    hlo='o';
    label="&altlabel";
    output;
  end; 
run;

proc format cntlin=cntlin; 
run;
 
%mend fmtmaker; 


