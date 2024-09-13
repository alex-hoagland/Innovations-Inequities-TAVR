/*
*========================================================================*
* Program:   TAVRPrices_2006.sas	                                 *
*                                                                        *
* Purpose:   This program pulls all TAVR/SAVR/PCI inpatient procs in     *
* 		Marketscan from 2006-2006				 * 
*            Each separate .sas file is for a specific year. This file's year is 2006.   *
*                                                                        *
* Author:    Alex Hoagland	         	                         *
*                                                                        *
* Created:   1/26/2022		                                         *
* Updated:   8/1/2024			                                 *
*========================================================================*;
*/

*Set libraries;
libname in '/projectnb2/marketscan/data/' access=readonly;
libname out '/project/sdoh-mod/IBNR/Alex_Code/1.IdentifyEvents/TAVR_PullMarketscanPrices/';

/*----------------*
 * Create samples *
 *----------------*/;

*Start with all inpatient claims, then keep only those with appropriate DRG; 
data out.inpatient_2006; 
  set in.ms_i_2006(keep=enrolid year drg pdx pproc admdate tot:);
  /* KEEP ONLY interventional cardiology + TAVR/SAVR*/; 
  if (drg >= 216 & drg <=320);
run; 

*Export claims; 
proc export data=out.inpatient_2006
    outfile = "/project/sdoh-mod/IBNR/Alex_Code/1.IdentifyEvents/TAVR_PullMarketscanPrices/TAVRPrices-Admissions_2006.dta"
    dbms=stata
    replace;
run; 

* Delete sas data; 
proc delete data=out.inpatient_2006; 
run; 
