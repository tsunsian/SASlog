/***************************************************************************************
**     Program Name:        decimal.sas
**     Programmer:          tsunsian
**     Date:                21-May-2021
**
**     Purpose:             Creates formats for decimal displays based on collected data 
**                          
**     Parameters:          inds=       (required) Input dataset; 
**                          dec_param=  (required) parameter or test name, deault is PARAM;  
**                          dec_value=  (required) analysis value, default is AVAL; 
**                          whercl=     (optional) Subsetting input dataset, 1 by default; 
**/    



%macro decimal(inds=, dec_param=PARAM, dec_value=AVAL, whercl=1); 

proc sql; 
  create table _decima as
  select &dec_param. as start, max(lengthn(scan(cats(&dec_value.),2,'.'))) as maxdec
  from &inds.
  where &whercl.
  group by start;
quit;

%* Create some user defined formats for use downstream; 
%local dp totl; 
%let totl=16;
%do dp=0 %to 10;
  proc format lib=work; 
  picture dec&dp.p (fuzz=0 round)
    low - <0 = %if &dp.=0 %then "%sysfunc(repeat(0,14))9"; 
  %else "%sysfunc(repeat(0,&totl.-&dp.-3))9.%sysfunc(repeat(9,&dp.-1))"; (prefix='-')
    0 - high = %if &dp.=0 %then "%sysfunc(repeat(0,14))9"; 
  %else "%sysfunc(repeat(0,&totl.-&dp.-3))9.%sysfunc(repeat(9,&dp.-1))";
    other    = ' ';
run;
%end; 

%fmtmaker(inds=_decima, fmtname=dp0more, type=c, start=start, label=cats('dec',maxdec+0,'p.'), altlabel=%str( )); 
%fmtmaker(inds=_decima, fmtname=dp1more, type=c, start=start, label=cats('dec',maxdec+1,'p.'), altlabel=%str( )); 
%fmtmaker(inds=_decima, fmtname=dp2more, type=c, start=start, label=cats('dec',maxdec+2,'p.'), altlabel=%str( )); 

%put NOTE: ==========================================================================================================; 
%put NOTE: The following formats have been created:                                                                  ; 
%put NOTE: DP0MORE. - keep the same # of decimal places as collected values, e.g. Min, Max, etc.                     ; 
%put NOTE: DP1MORE. - keep one more decimal place than collected values, e.g. Mean                                   ;
%put NOTE: DP2MORE. - keep two more decimal places than collected values, ue.g. deviation                            ; 
%put NOTE: Example: mean_sd = PUTN(mean,PUT(param,DP1MORE.))||' ('||STRIP(PUTN(sd,PUT(param,DP2MORE.))))||')'%str(;) ;  
%put NOTE: ==========================================================================================================; 


%mend decimal; 


  
