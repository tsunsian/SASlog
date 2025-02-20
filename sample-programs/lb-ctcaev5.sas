/***********************************************************************************************
**  Program Name:      ctcv5.sas
**  Programmer:        tsunsian
**  Date:              12-APR-2021
**  Purpose:           Grade lab tests based on CTCAEv5
**/

proc datasets nolist lib=work memtype=data kill;
run;
quit;

%* configuration;
%*  %inc statement below is just to make testing easier, to be removed when moving to production; 
%inc %sysfunc(quote(%sysfunc(prxchange(s#(/gbs/[a-z0-9/-]+/)[^/]+#$1#, -1, %sysfunc(ifc("%sysfunc(getoption(sysIn))" ne "", 
  %sysfunc(getoption(sysIn)), %nrstr(&_sasprogramfile.)))))autoexec.sas)); 
**************************************************************************************************; 


%* CTCv5 criteria; 
proc import datafile="&cwd./CTC v5 12June2020.xlsx" 
  out=CTC(where=(criteria_code is not null)) replace dbms=xlsx;
  sheet="INT"; 
run;

proc freq data=ctc noprint; 
  tables test_code*test_name*sdtm_unit/out=_tests;
run;

%checkUnik(inds=_tests, bykeys=test_code test_name sdtm_unit, msgtype=w); 

** Categorize CTCv5 for ease of processing at later stage; 
* "A" - Abnormal/normal baseline, e.g. ALT, ALP, AST, TBILI, GGT;  
* "B" - Bidirectioanl, e.g. CA, processed similarly as "R"; 
* "C" - Conversion needed, e.g. LYMPH, not processed in this program; 
* "R" - Regular, e.g. ALB; 
* "S" - Symptomatic/asymptomatic, e.g. AMYPL, SODIUM; 
* "T" - Two possible grades, e.g. CREAT, processed similiar as "R"; 
* .... more category to add? ;
proc sort data=ctc out=ctc_sorted;
  where toxicity in ('HIGH','LOW'); 
  by test_code baseline_abnormal toxicity cSMQ_check grade; 
run;

data ctccat; 
  length grades new_direction ctc_cat cat1-cat5 $20;
  do until (last.test_code);
    set ctc_sorted; 
    by test_code baseline_abnormal toxicity cSMQ_check grade; 
    if baseline_abnormal in ('Y','N') then cat1='A'; 
    if toxicity ne new_direction and new_direction ne '' then cat2='B'; 
    else new_direction=toxicity;
    if type='Relative' then cat3='C';
    if prxmatch('/symptomatic/i',cSMQ_check) then cat4='S';      
    if first.cSMQ_check then call missing(grades); 
    if index(grades,cats(grade)) then cat5='T'; 
    else grades=cats(grades,grade);
  end; 
  ctc_cat=coalescec(cats(of cat1-cat5),'R'); 
run;

data ctc_updated;
  set ctc;
  %hashmerge(inds=ctccat, inkeys=test_code, invarlist=ctc_cat);
  if ctc_cat='C' then delete; 
run;



%* pre-processing SDTM.LB ;
data lb;
  set sdtm.lb; 
  where prxmatch('/^(chemistry|coagulation|hematology)/i', lbcat);
run;

proc freq data=lb noprint; 
  tables lbcat*lbtestcd*lbtest/out=sdtm_tests; 
  where lbstat='';
run;

%checkunik(inds=sdtm_tests, bykeys=lbcat lbtestcd lbtest, msgtype=w); 


** Match sdtm test codes with  CTCv5 criteria test codes - the opposite route probably makes more sense; 
proc format; 
  value $ctctests (default=8)
  'BILI'='TBILI'
/*   'GLUC'='GLUCF'  */
  'SODIUM'='NA'
  'HGB'='HB'
  'LYM'='LYMPA'
  'LYMLE'='LYMPH'
  'NEUT'='NEUTA'
  'NEUTLE'='NEUT'
/*   'TRIG'='TRIGF' */
  ;
run;

* check fasting status; 
proc freq data=lb noprint; 
  tables lbcat*lbtestcd*lbtest*lbfast*visitnum*visit/out=check0;
  where lbtestcd in ('GLUC','TRIG'); 
run;

* match update LBTESTCD in lb2; 
data lb2; 
  set lb; 
  test_code=put(lbtestcd,$ctctests.);
  if lbtestcd in ('GLUC','TRIG') then test_code=cats(lbtestcd, ifc(lbfast='Y','F','')); 
  %hashmerge(inds=_tests, inkeys=test_code, invarlist=test_name sdtm_unit); 
  if not missing(test_name) then to_be_graded='Y'; 
run;

proc freq data=lb2 noprint; 
  tables lbtestcd*lbtest*test_code*to_be_graded/out=check1;
run;


** Update units in SDTM.LB; 
proc freq data=lb2 noprint; 
  tables test_code*lbtest*to_be_graded*lbstresu*sdtm_unit/out=check2; 
  where lborres is not null; 
run;

%checkUnik(inds=check2, bykeys=test_code lbtest to_be_graded lbstresu sdtm_unit, msgtype=w); 

data check3; 
  set check2; 
  if to_be_graded='Y' and lbstresu ne sdtm_unit then do; 
    if lbstresu not in ('IU/L','%') then put 'WAR' 'NING: LBSTRESU might not be SI ' lbstresu=;
    output;
  end; 
run;

%checkunik(inds=lb2, bykeys=usubjid lbtestcd visit, msgtype=w, whercl=%str(lbtestcd in ('WBC'))); 

* get absolute counts for LYMPH and NEUT - not required for grading;
data wbccounts; 
  set lb2; 
  where lbtestcd='WBC'; 
  lbtestcd='LYMLE'; output; 
  lbtestcd='NEUTLE'; output; 
  rename lbstresn=wbc lbstresu=wbcu lbstnrlo=wbclow lbstnrhi=wbchigh;
  keep lbrefid usubjid lbtestcd visit lbstresu lbstresn lbstnrlo lbstnrhi;
run;

data lb3; 
  set lb2; 
  if lbstresu='IU/L' then lbstresu='U/L';
  %hashmerge(inds=wbccounts, inkeys=lbrefid usubjid lbtestcd visit, invarlist=wbc wbcu wbclow wbchigh); 
  if lbtestcd in ('LYMLE','NEUTLE') then do; 
    if lbtestcd='LYMLE' then test_code='LYMPA';
    else if lbtestcd='NEUTLE' then test_code='NEUTA'; 
    if cmiss(lbstresn,wbc)=0 then do;
      lbstresn=wbc*lbstresn; 
      lbstresu=wbcu; 
      lbstnrlo=wbclow*lbstnrlo;
      lbstnrhi=wbchigh*lbstnrhi;
    end; 
    else call missing(lbstresn, lbstresu, lbstnrlo, lbstnrhi); 
    to_be_graded='N'; * absolute is greaded instead; 
  end; 
  drop wbc:; 
run;


** copy baseline onto post-baseline records; 
* re-derive baseline - pick the least toxic when there are competing records based on time proximity; 
* For ALP, AST, ALT, TBILI, GGT, CREAT: higher = more toxic;  
data lb4; 
  set lb3; 
  %hashmerge(inds=sdtm.dm, inkeys=usubjid, invarlist=rfxstdtc); 
  if '' < substrn(lbdtc,1,10) <= rfxstdtc and not missing(lbstresc) then qualified=1;
run; 
proc sort data=lb4;
  by usubjid lbcat lbtestcd qualified lbdtc lbstresn; 
run;

data lb5; 
  set lb4; 
  by usubjid lbcat lbtestcd qualified lbdtc lbstresn; 
  if last.qualified and qualified=1 then mylbblfl='Y'; 
  if mylbblfl ne lbblfl then put 'WAR' "NING: The derived baseline flag is different from vendor's.";
  drop lbblfl qualified; 
  rename mylbblfl=lbblfl; 
run; 

proc sort data=lb5; 
  by usubjid lbcat lbtestcd lbdtc lbblfl; 
run;

data lb6; 
  set lb5; 
  by usubjid lbcat lbtestcd lbdtc lbblfl;
  retain baseline; 
  if first.lbtestcd then call missing(baseline);
  if lbblfl='Y' then baseline=lbstresn;
  if test_code in ('ALP','ALT','AST','TBILI','GGT') and not missing(baseline) and lbblfl='' then base_abn=ifc(baseline>lbstnrhi>.,'Y',''); 
run;

proc freq data=lb6 noprint; 
  tables lbcat*lbtestcd*test_code*lbstresu*lbstnrlo*lbstnrhi/out=check4;
  where to_be_graded='Y' and lbstresc is not null;
run;


** symptomatic/asymptomatic for sodium (low); 
%checkunik(inds=csmqref.ctcv5ref, bykeys=aeptcd aedecod, msgtype=n); 

* Qualified AEs;
data ae;
  set sdtm.ae; 
  %hashmerge(inds=csmqref.ctcv5ref, inkeys=aeptcd, invarlist=cqnam, whercl=%str(prxmatch('/HYPONATRAEMIA/',cqnam)));
  %hashmerge(inds=sdtm.dm, inkeys=usubjid, invarlist=rfxstdtc rficdtc);
  %hashmerge(inds=sdtm.ds, inkeys=usubjid, invarlist=dsstdtc, whercl=%str(dsdecod='RANDOMIZED'), rename=%str(dsstdtc=randdtc)); 
  if not missing(cqnam); 
  firstdate=input(coalescec(rfxstdtc,randdtc,rficdtc),??e8601da.); 
  format firstdate yymmdd10.;
  if aeenrtpt='ONGOING' and missing(aestdtc) then aestdtc=put(firstdate-1,e8601da.); 
  if cmiss(aestdtc,aeendtc)=2 and prxmatch('/\/RESOLVED/',aeout) then do; 
    aestdtc=put(firstdate-1,e8601da.);
    aeendtc=put(firstdate-1,e8601da.);
  end; 
  aeendtc=coalescec(aeenrtpt,aeendtc); 
  if aeenrtpt ne 'ONGOING' and missing(aeendtc) then put 'WAR' 'NING: ' AESTDTC= AEENDTC= AEENRTPT=; 
run;

%checkunik(inds=ae, bykeys=usubjid aedecod, msgtype=w); * alert if multiple records of the same PT; 

* flag for symptomatic/asymptomatic;
data lb7; 
  if _n_=1 then do;
    if 0 then set ae(keep=aestdtc aeendtc aedecod);
    dcl hash h(dataset: 'ae', multidata: 'y');
    h.definekey('usubjid');
    h.definedata('aestdtc','aeendtc','aedecod');
    h.definedone();
  end; 
  set lb6; 
  if not missing(lbdtc) and lbtestcd='SODIUM' then do; 
    rc=h.find(); 
    if rc>0 then symptom='N';
    else do rc=0 by 0 while (rc=0);
      if '' < aestdtc < put(input(lbdtc,e8601da.)-14,e8601da.) then do; 
        if aeendtc ne 'ONGOING' and '' < aeendtc < put(input(lbdtc,e8601da.)-14,e8601da.) then symptom='N';
        else symptom='Y'; 
      end; 
      else if put(input(lbdtc,e8601da.)+14,e8601da.) < aestdtc then symptom='N'; 
      else if not missing(aestdtc) then symptom='Y';  
      rc=h.find_next(); 
    end; 
  end; 
  drop ae: rc; 
run;

data lb_target; 
  set lb7; 
run;

data sasout.lb; 
  set sdtm.lb;
  %hashmerge(inds=lb_target, inkeys=usubjid lbseq, invarlist=test_code to_be_graded baseline base_abn symptom lbstresu, 
     rename=%str(lbstresu=si_unit)); 
  if to_be_graded='Y' then do; 
     if lbstresu ne si_unit then lbstresu=si_unit;  
     if lbtestcd ne test_code then lbtestcd=test_code;
  end; 
run;


%* perform CTC grading;  
proc fcmp outlib=work.functions.conversion; 
  * function to replace ULN/LLN/BASELINE with value of lbstnrhi/lbstnrlo/baseline; 
  function tidyr(invar $, uln, lln, base); 
    if invar='ULN' then x=uln; 
    else if invar='LLN' then x=lln; 
    else if invar='BASELINE' then x=base; 
    else if anyalpha(invar) then put 'WARNING: Unexpected values detected in the $invar argument: ' invar=; 
    else if not missing(invar) then x=input(invar,best.);
    return(x); 
  endsub;
  
  * function to peform evaluation based on operator; 
  function evaluate(operator $, operand_rslt, operand_lmt); 
    if missing(operator) then return(1); 
    if cmiss(operand_rslt,operand_lmt) = 0 then do; 
      if operator='>' then x=(operand_rslt > operand_lmt);
      else if operator='>=' then x=(operand_rslt >= operand_lmt);
      else if operator='<' then x=(operand_rslt < operand_lmt);
      else if operator='<=' then x=(operand_rslt <= operand_lmt);
      else if operator='=' then x=(operand_rslt = operand_lmt);
    end; 
    else x=0;
    return(x); 
  endsub; 
run;

options cmplib=(work.functions);


** gradings; 
data lb_ctc; 
  if _n_=1 then do; 
    if 1>2 then set ctc_updated(keep=grade toxicity baseline_abnormal cSMQ_check low_: high_: comment ctc_cat); 
    dcl hash c(dataset: 'ctc_updated(rename=(sdtm_unit=lbstresu))', multidata: 'y'); 
    c.definekey('test_code','lbstresu'); 
    c.definedata('ctc_cat','grade','toxicity','baseline_abnormal','cSMQ_check','low_operator','low_value','low_multiplier',
                 'high_operator','high_value','high_multiplier','comment');
    c.definedone();
  end; 
  
  call missing(of _all_); 
  set lb_target;
  if to_be_graded='Y' and not missing(lbstresn) then do rc=c.find() by 0 while(rc=0);  
    * prepare lower end and uppper end;
    call missing(lower_end,upper_end,missing_end);
    if not missing(comment) then missing_end=input(prxchange('s/.*USE\s+DEFAULT\s+([.0-9]+)\b.*/$1/si',-1,comment),??best.);
    if not missing(low_operator) then do; 
      lower_end=tidyr(low_value,lbstnrhi,lbstnrlo,baseline);
      if prxmatch('/^[UL]LN$/',cats(low_value)) and missing(lower_end) then lower_end=missing_end;
      lower_end=lower_end*coalesce(low_multiplier,1.0); 
      if missing(lower_end) and low_value ne 'BASELINE' then put 'WARNING: LOWER_END is missing for ' usubjid= test_code=;  
    end; 
    if not missing(high_operator) then do; 
      upper_end=tidyr(high_value,lbstnrhi,lbstnrlo,baseline);
      if prxmatch('/^[UL]LN$/',cats(high_value)) and missing(upper_end) then upper_end=missing_end;
      upper_end=upper_end*coalesce(input(high_multiplier,best.),1.0); 
      if missing(upper_end) and high_value ne 'BASELINE' then put 'WARNING: UPPER_END is missing for ' usubjid= test_code=; 
    end; 
      
    * regulars or symptomatic/asymptomatic or abnormal baseline; 
    if prxmatch('/[AS]/', ctc_cat)=0 or 
       (prxmatch('/S/', ctc_cat) and (cSMQ_check='NA' or (symptom='N' and cSMQ_check='ASYMPTOMATIC') or (symptom='Y' and cSMQ_check='SYMPTOMATIC'))) or 
       (prxmatch('/A/', ctc_cat) and ((base_abn='' and baseline_abnormal='N') or (base_abn='Y' and baseline_abnormal='Y'))) then do; 
      if evaluate(low_operator,lbstresn,lower_end) and evaluate(high_operator,lbstresn,upper_end) then do; 
        mytoxicity=toxicity;
        mygrade=max(mygrade,input(grade,best.)); 
      end; 
    end; 
    
    rc=c.find_next();
  end; 
  if to_be_graded='Y' and c.find()>0 and not missing(lbstresn) then put 'WARNING: Test and unit not matched with  CTCv5 ' TEST_CODE= LBSTRESU= ; 
  drop grade toxicity baseline_abnormal cSMQ_check low_: high_: comment ctc_cat rc lower_end upper_end missing_end; 
  rename mytoxicity=toxicity mygrade=grade; 
run;

** output;
data sasout.lb_ctc;
  set sdtm.lb;
  %hashmerge(inds=lb_ctc, inkeys=usubjid lbseq, invarlist=grade to_be_graded toxicity test_code baseline base_abn symptom lbstresu, 
    rename=%str(lbstresu=si_unit));
  if to_be_graded='Y' then do; 
    if lbstresu ne si_unit then lbstresu=si_unit;  
    if lbtestcd ne test_code then lbtestcd=test_code;
  end; 
run;

