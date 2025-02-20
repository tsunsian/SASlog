/***************************************************************************************
**     Program Name:        hashmerge.sas
**     Programmer:          tsunsian
**     Date:                12-Apr-2021
**
**     Purpose:             Bring variables from another dataset to the current DATA step loop for manipulations
**     Parameters:          inds=      (required) Input dataset; 
**                          inkeys=    (required) Key variables for merge/join; 
**                          invarlist= (required) Target variables to be brought in the current DATA step; 
**                          whercl=    (optional) Where clause to subset the input dataset in case of need; 
**                          rename=    (optional) Rename target variables to avoid conflict with the PDV of the current DATA step;
**/     



%macro hashmerge(inds=, inkeys=, invarlist=, whercl=1, rename=); 

%* validate parameters; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 
%if "&inkeys." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Key variables cannot be missing. Macro will terminate.; 
  %abort; 
%end;
%if "&invarlist." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Data variables cannot be missing. Macro will terminate.; 
  %abort; 
%end;


%* tidy parameters; 
%local lc_rename oldvar newvar lc_inkeys lc_invarlist inkeys_quoted invarlist_quoted invarlist_comma i; 

%let lc_rename=%qsysfunc(prxchange(s/\s*=\s*/=/,-1,%qcmpres(&rename.))); 
%let lc_invarlist=%cmpres(&invarlist.)%str( ); 

%let i=1; 
%if "%superq(lc_rename)" ne "" %then %do %while(%scan(&lc_rename.,&i.,%str( )) ne );
  %let oldvar=%scan(%qscan(&lc_rename.,&i.,%str( )), 1, %str(=));
  %let newvar=%scan(%qscan(&lc_rename.,&i.,%str( )), 2, %str(=));
  %let lc_invarlist=%qsysfunc(prxchange(s/&oldvar. /&newvar. /,-1,%bquote(&lc_invarlist.))); 
  %let i=%eval(&i.+1); 
%end; 

%let lc_inkeys=%cmpres(&inkeys.);
%let inkeys_quoted=%str(%")%qsysfunc(tranwrd(&lc_inkeys.,%str( ),%str(",")))%str(%"); 
%let lc_invarlist=%cmpres(&lc_invarlist.); 
%let invarlist_quoted=%str(%")%qsysfunc(tranwrd(&lc_invarlist.,%str( ),%str(",")))%str(%"); 
%let invarlist_comma=%qsysfunc(tranwrd(&lc_invarlist.,%str( ),%str(,)));
%put NOTE: &=lc_rename; 
%put NOTE: &=lc_inkeys;
%put NOTE: &=lc_invarlist; 
%put NOTE: &=inkeys_quoted;
%put NOTE: &=invarlist_quoted;
%put NOTE: &=invarlist_comma; 


%* keep track of object names; 
%global _num_hobj; 
%if %eval(&_num_hobj. < 1) %then %let _num_hobj=1;
%else %let _num_hobj=%eval(&_num_hobj.+1); 
%local _hobj; 
%let _hobj=_obj_&_num_hobj.;


%* hash object definition; 
if _n_=1 then do; 
  if 0 then set &inds.(keep=&invarlist. rename=(%bquote(&lc_rename.))); 
  dcl hash &_hobj. (dataset: %sysfunc(quote(&inds(where=(%unquote(%nrbquote(&whercl.))) rename=(%bquote(&lc_rename.))))));
  &_hobj..definekey(%unquote(&inkeys_quoted.)); 
  &_hobj..definedata(%unquote(&invarlist_quoted.));
  &_hobj..definedone(); 
end; 


%* preform many-to-one merge; 
if &_hobj..find() then call missing(&invarlist_comma.);


%mend hashmerge;



