/***************************************************************************************
**     Program Name:        splitbyword.sas
**     Programmer:          tsunsian
**     Date:                19-Apr-2021
**
**     Purpose:             Split long strings between words (without breaking any words)
**                          
**     Parameters:          inds=       (required) Input dataset; 
**                          splitvar=   (required) Variable to be split;  
**                          outds=      (optional) Output dataset, default to &inds; 
**                          linesize=   (optional) Max length at which splitting is forced, 
**                                        default to the value of the LINESIZE system option; 
**                          splitchar=  (optional) Delimiter of words, default to a single space; 
**                          newvarname= (optional) Prefix for the variables that hold the split chunks, 
**                                        ie, newvarname0, newvarname1, newvarname2, ..., default to &splitvar; 
***/


%macro splitbyword(inds=, outds=&inds., splitvar=, linesize=%sysfunc(getoption(LS)), splitchar=%str( ), newvarname=&splitvar.); 

%* parameter validation; 
%if "&inds." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set is missing. Macro will terminate.; 
  %abort; 
%end;
%if not %sysfunc(exist(&inds.)) %then %do; 
  %put %str(E)RROR: [&sysmacroname] Input data set %upcase(&inds) doesn%str(%')t exist. Macro will terminate.; 
  %abort; 
%end; 
%if "&splitvar." eq "" %then %do; 
  %put %str(E)RROR: [&sysmacroname] Splitting variable name is missing. Macro will terminate.; 
  %abort; 
%end;
proc sql noprint; 
  select * from dictionary.columns
  where libname="%upcase(%sysfunc(ifc(%index(&inds.,.),%scan(&inds.,1,.),work)))" and 
        memname="%upcase(%sysfunc(ifc(%index(&inds.,.),%scan(&inds.,2,.),&inds.)))" and 
        memtype="DATA" and upcase(name)="%upcase(&splitvar.)" and type='char';
quit;
%if &sqlobs.=0 %then %do; 
  %put %str(E)RROR: [&sysmacroname] Character variable %upcase(&splitvar) doesn%str(%')t exist. Macro will terminate.; 
  %abort;
%end; 

%* The following intermediate variables are created: ;  
%* _smallBox: small box - box of words;
%* _largeBox: large box - box of small boxes, ie box of vars;
%* _wordCounter: counter of words;
%* _word: word itself; 
%* _wordLenth: length of word; 
%* _num_splitVars: # of split vars - the size of large box; 
%* _tempString: temporary container of a random number of words; 

%* macro to construct the small box and large box; 
%macro h_constructor; 
  length _word $%eval(&linesize.*2) _wordCounter _num_splitVars 8; 
  if _n_=1 then do; 
    dcl hash _smallBox;
    dcl hiter _smallBox_i; 
    _smallBox = _new_ hash(ordered: 'y'); 
    _smallBox.definekey('_wordCounter');
    _smallBox.definedata('_word');
    _smallBox.definedone(); 
    
    dcl hash _largeBox (ordered: 'y'); 
    _largeBox.definekey('_num_splitVars');
    _largeBox.definedata('_smallBox');
    _largeBox.definedone(); 
    call missing(_word, _wordCounter, _num_splitVars); 
  end; 
%mend h_constructor;

%* macro to perform splitting; 
%macro h_splitStr(debug=Y);
    _smallBox.clear(); 
    _largeBox.clear(); 
    _wordCounter=1; 
    _num_splitVars=1; 
    length _tempString $%eval(&linesize.*2); 
    call missing(_tempString,_word); 
    _&splitvar.=&splitvar.;
    _&splitvar.=compbl(prxchange('s/[\f\n\r\t]/ /',-1,_&splitvar.)); 
    
    do while(scan(_&splitvar.,_wordCounter,"&splitchar.") ne ''); 
      _word=scan(_&splitvar.,_wordCounter,"&splitchar."); 
      _wordLenth=length(_word); 
      if _wordLenth > &linesize. then do; 
      %if &debug.=Y %then %do; 
        put 'WAR' 'NING:[QC] Observation ' _n_ "was not split due to detection of at least one word longer than &linesize.." /
            "The word is " _word "/ the length is " _wordLenth; 
      %end; 
        leave; 
      end; 
      else _tempString=catx("&splitchar", _tempString, _word);  
      if length(_tempString) + lengthc("&splitchar") <= &linesize. then _smallBox.add(); 
      else do; 
        _largeBox.add(); 
        _num_splitVars+1; 
        _smallBox = _new_ hash(ordered: 'y');
        _smallBox.definekey('_wordCounter');
        _smallBox.definedata('_word');
        _smallBox.definedone(); 
        _smallBox.add(); 
        _tempString=_word; 
      end;
      _wordCounter+1; 
    end; 
    
    if _smallBox.num_items gt 0 then _largeBox.add(); 
%mend h_splitStr;


%* find out the maximum number of variables after splitting; 
%global max_nsplitvars; * This global macro variable can be used for subsequent processing the split variables; 

data _null_; 
  %h_constructor; 
  do until (eof); 
    set &inds. end=eof; 
    %h_splitStr(debug=N); 
    max_num_of_vars=max(max_num_of_vars, _largeBox.num_items); 
  end; 
  call symputx('max_nsplitvars', max_num_of_vars);
  stop;
run;
%put NOTE: [&sysmacroname] The global macro variable %nrstr(&max_nsplitvars) has been created: &=max_nsplitvars;


%* splitting &splitvar by word; 
data &outds.;
  %h_constructor; 
  set &inds. end=eof;
  
  %h_splitStr(debug=Y);
  
  %* reconstruct the post-splitting variables from the large box and the small boxes inside it; 
  array asplitvars{*} $&linesize. &newvarname.0 %if &max_nsplitvars.>1 %then - &newvarname.%eval(&max_nsplitvars.-1);;
  do i=1 to _largeBox.num_items;
    _largeBox.find(key:i);
    _smallBox_i = _new_ hiter('_smallBox'); 
    do while (_smallBox_i.next()=0); 
      asplitvars[i]=catx("&splitchar", asplitvars[i], _word); 
    end; 
    if i < _largeBox.num_items /*and lengthn("&splitchar")*/ then asplitvars[i]=cats(asplitvars[i])||"&splitchar"; 
  end; 
  drop _word _wordCounter _num_splitVars _wordLenth _tempString _&splitvar. i; 
run;

%mend splitbyword; 



