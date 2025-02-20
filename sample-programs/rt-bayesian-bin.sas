/***********************************************************************************************
**  Program Name:      q-rt-ef-bays-p50b-ra.sas
**  Programmer:        tsunsian
**  Date:              04-Nov-2021**/


proc datasets library=work kill nolist;
quit;

%* configuration;
%*  %inc statement below is to make testing easier, may be removed before moving to production; 
%inc %sysfunc(quote(%sysfunc(prxchange(s#(/gbs/[a-z0-9/-]+/)[^/]+#$1#, -1, %sysfunc(ifc("%sysfunc(getoption(sysIn))" ne "", 
  %sysfunc(getoption(sysIn)), %nrstr(&_sasprogramfile.)))))autoexec.sas)); 

%let outputname=rt-ef-bays-p50b-ra.lst;
%let outputno=Table S.5.1.2.3; 
filename outfile "&outputdir/&outputname.";
*****************************************************************************************************;

proc format;
  picture est (round fuzz=0)
    low - <0  = '000000009.999' (prefix='-')
    0         = '0' (noedit)
    0< - high = '000000009.999'
    other     = ' '
    ;
run;

  
%*** prepare source data;
data adeff; 
  set level2.adeff end=eof;
  where fasfl='Y' and paramcd='P50' and avisit='Week 12' and anl01fl='Y';
  retain trt trtn pbo pbon 0;
  if trt01p='DUMMYA' then do; 
    trtn+1;
    trt+(avalc='Y');
  end;
  else if trt01p='DUMMYB' then do;
    pbon+1;
    pbo+(avalc='Y');
  end;
  totn+1;
  if eof then do; 
    call symputx('npbo',pbon);
    call symputx('ntrt',trtn);
    output;
  end; 
  keep trt trtn pbo pbon;
run;

** historical controls data - from IM014-029 IA Unblinding Plan.docx;
data hist;
  infile datalines;
  input histn hist;
  index+1;
datalines;
475 94
46 9
44 5
170 13
110 16
51 12
49 4
61 13
;
run;



%*** Bayesian analyses; 
%* [1] no historical control borrowing;
ods output PostSumInt=psi1;
proc mcmc data=adeff seed=1001 nbi=2000 nmc=10000 /*STATS=all*/ monitor=(_parms_ trteff) outpost=outpost1;
  parms p q;
  
  beginnodata;
    prior p q ~ beta(0.05, 0.05);
    trteff=(p-q);
  endnodata;
  
  model trt ~ binomial(trtn, p);
  model pbo ~ binomial(pbon, q); 
run;
  


%* [2] MAP hostorical control borrowing;
data _null_; 
  if 0 then set hist nobs=n;
  call symputx('nhist',n);
  stop;
run;

data adeff_h;
  set adeff;
  array ahist{*} hist1-hist&nhist.;
  array ahistn{*} histn1-histn&nhist.;
  do i=1 to &nhist.;
    set hist point=i;
    ahist[i]=hist;
    ahistn[i]=histn;
  end;
  drop hist histn;
run;

%macro gen(n=&nhist.);

ods output PostSumInt=psi2;
proc mcmc data=adeff_h seed=1002 nbi=2000 thin=20 nmc=200000 monitor=(_parms_ p pc pt theta trteff) outpost=outpost2; 
  array theta[&n.];
  array p[&n.];
  
  parms mu tau;
  parms theta_t;

  beginnodata;
    prior mu ~ normal(0, var=1e4);
    prior tau ~ cauchy(0, 2.5, lower=0); *normal(0, var=1e4, lower=.001);
    prior theta_t ~ normal(0, var=1e4);
  endnodata;

%do i=1 %to &n.;
  random theta&i. ~ normal(mu, sd=tau) subject=index;
  p&i. = logistic(theta&i.);
  model hist&i. ~ binomial(histn&i., p&i.);
%end; 
  random theta_c ~ normal(mu, sd=tau) subject=index;
  pt = logistic(theta_t);
  pc = logistic(theta_c);
  trteff=pt-pc;
  model pbo ~ binomial(pbon, pc);
  model trt ~ binomial(trtn, pt);
run;

%mend gen;

%gen;




%* [3] empirical power prior historical control borrowing;
** computing overlapping coefficients thru numerical integration;
proc iml;
  * read in data;
  use hist;
  read all var {'hist' 'histn'} into hist;
  close hist;
  use adeff;
  read all var {'pbo' 'pbon'} into pbo;
  close adeff;
  
  * parameters for beta prior;
  a=0.05;
  b=0.05;
  
  * modules;
  start intPost(x) global(event,n,a,b);
    return(pdf('binomial',event,x,n) * pdf('beta',x,a,b));
  finish;
  
  start intMinPost(x) global(norc1,norc2,a,b,h,nh,p,np);
    v=min(norc1*pdf('binomial',p,x,np)*pdf('beta',x,a,b), norc2*pdf('binomial',h,x,nh)*pdf('beta',x,a,b));
    return(v);
  finish;
  
  * normalizing constant for current data;
  event=pbo[1,1];
  n=pbo[1,2];
  call quad(intP, 'intPost', {0 1});
  norc1=1/intP;
  
  p=pbo[1,1];
  np=pbo[1,2];
  do i=1 to nrow(hist);
    * normalizing constant for historical data;
    event=hist[i,1];
    n=hist[i,2];
    call quad(intH, 'intPost', {0 1}); 
    norc2=1/intH;

    * overlapping coefficient;
    h=hist[i,1];
    nh=hist[i,2];
    call quad(intM, 'intMinPost', {0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1});
    ovl=ovl || intM;
  end; 
  a0=ovl[+,]`;
  
  * output the overlapping coefficients;
  index=1:8;
  create overlap var {'index' 'a0'};
  append;
  close overlap; 
quit;

data hist_pw;
  set hist;
  %hashmerge(inds=overlap, inkeys=index, invarlist=a0);
run;

** apply power prior; 
ods output PostSumInt=psi3;
proc mcmc data=adeff seed=1003 nbi=2000 nmc=10000 monitor=(_parms_ trteff pred1-pred4) outpost=outpost3;
  parms p q;
  array hdata[1] / nosymbols;
  
  begincnst;
    rc = read_array("hist_pw", hdata, "hist", "histn", "a0"); 
    q = 0.1; * assigning initial value for q;
  endcnst;

  beginnodata;
    * prior for placebo;
    lq = 0;
    do j = 1 to dim(hdata, 1); 
      lq = lq + hdata[j,3] * logpdf("binomial", hdata[j,1], q, hdata[j,2]) + logpdf('beta',q,0.05,0.05); 
    end;
    prior q ~ general(lq); 
    
    * prior for trt;
    prior p ~ beta(0.05, 0.05); 
    trteff=p-q;
    pred1=(trteff>0);
    pred2=(trteff>0.15);
    pred3=(trteff>0.20);
    pred4=(trteff>0.35);
  endnodata;
    
  model pbo ~ binomial(pbon, q);
  model trt ~ binomial(trtn, p);
run;



%*** combine ;
data final;
  length cat 8 lab dummyb dummya $200; 
  set adeff 
      psi1(where=(parameter in ('p','q','trteff'))) 
      psi2(where=(parameter in ('pt','pc','trteff'))) 
      psi3(where=(parameter in ('p','q','trteff')))
      psi3(where=(prxmatch('/pred\d/',parameter)))
      indsname=src;  
  retain dummya dummyb;
  array athr{4} $10 _temporary_ ('0' '0.15' '0.20' '0.35'); 
  ds=scan(src,2,'.');
  
  if ds='ADEFF' then do; 
    cat=0;
    lab='RESPONDERS (%)';
    if pbo>0 then dummyb=put(pbo,2.)||put(100*pbo/pbon,pct.);
    else dummyb=put(pbo,2.);
    if trt>0 then dummya=put(trt,2.)||put(100*trt/trtn,pct.);
    else dummya=put(trt,2.);
    output; 
    call missing(of dummy:);
  end; 
  
  else if ds in ('PSI1','PSI2','PSI3') then do; 
    cat=input(compress(ds,'','a'),best.);
    lab='RESPONSE RATE (95% CI)';
    if parameter in ('q','pc') then dummyb=cats(put(mean,est.))||' ('||cats(put(HPDLower,est.))||', '||cats(put(HPDUpper,est.))||')';
    else if parameter in ('p','pt') then dummya=cats(put(mean,est.))||' ('||cats(put(HPDLower,est.))||', '||cats(put(HPDUpper,est.))||')';
    if parameter='trteff' then do; 
      output;
      call missing(of dummy:);
      lab=cats('Treatment Effect (95% CI)[',compress(ds,'','a'),']');
      dummya=cats(put(mean,est.))||' ('||cats(put(HPDLower,est.))||', '||cats(put(HPDUpper,est.))||')';
      dummyb='N.A.';
      output; 
    end; 
    if prxmatch('/pred\d/',parameter) then do; 
      cat=cat+input(compress(parameter,'','a'),best.); 
      dummyb='N.A.';
      dummya=cats(put(mean,est.));    
      lab=catx('','BPP(Treatment Effect >',cats(athr[input(compress(parameter,'','a'),best.)])||')[3]');
      output;
    end; 
  end; 
run;




