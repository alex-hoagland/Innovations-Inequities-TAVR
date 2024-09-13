/*******************************************************************************
* Title: Update flag for all patients with AS 
* Created by: Alex Hoagland
* Created on: 1/11/2022
* Last modified on: 3/2022
* Last modified by: 
* Purpose: updates the flag for AS diagnoses based on inpatient AND outpatient claims 
		- also builds a set of TAVR/SAVR/PCI eligible patients based on matching
		  diagnosis codes in outpatient data

* Notes: - uses files created in earlier code + outpatient files

* Key edits: -- Feb 2023: updated to build "universe" of TAVR/SAVR/PCI patients 
			based on diagnostic codes for surgery candidates + 20% OP file
*******************************************************************************/


***** 1. Start with universe of surgeries, keep TAVR/SAVR/PCI diagnosis codes  
use prncpal_dgns_cd tavr savr icd_prcdr_cd* surg_dt group /// 
	using "$datadir/all_InpatientCardiology.dta", clear 
do "$allcode/FRAC_ID_PTCA2.do"
keep if tavr == 1 | savr == 1 | ptca == 1
gen count = 1 
gcollapse (sum) count, by(*dgns*) fast
gen icd_ver = substr(prnc, 1, 1)
destring icd_ver, replace force
replace icd_ver = 0 if !missing(icd_ver)
replace icd_ver = 1 if missing(icd_ver) // icd-9 or 10 
bysort icd_ver: egen perc = total(count) 
replace perc = count / perc * 100
keep if perc > .5 // more than 0.5% of surgeries -- this is ~50 diagnoses, 85% of all surgeries	

// Pull patient information (not claims, for now)
keep *dgns* 
duplicates drop

// Pull all pateints, assign an AS flag 
forvalues yr = 2010/2017 { 
	di "***** MERGING CLAIMS FROM YEAR `yr' ******************************************************************************"
	
	preserve
	rename *dgns* icd_dgns_cd1 
	merge 1:m icd_dgns_cd1 using /disk/aging/medicare/data/harm/20pct/car/`yr'/carc`yr'.dta, ///
		keep(3) nogenerate
	gen tokeep = 0 
	forvalues i = 1/5 { 
		replace tokeep = 1 if inlist(icd_dgns_cd`i', "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(icd_dgns_cd`i', "3968", "3969", "3979", "4241") // ICD-9
		replace tokeep = 1 if inlist(substr(icd_dgns_cd`i',1,4), "I060", "I061", ///
			"I062", "I068", "I069", "I080", "I088", "I089") | ///
			inlist(icd_dgns_cd`i',"I350", "I351","I352") // ICD-10
	}
	rename tokeep as_flag
	gcollapse (max) as_flag, by(bene_id) fast
	gen year = `yr'
	save "$datadir/toappend_`yr'.dta", replace
	restore
}

// TODO: start with inpatient surgeries and collapse to enrollee-yq level. 
// Then merge in demographic information and anything needed to predict risk at the year-quarter level
// Ultimate goal: show pr(any surgery) changes after adoption, and changes more for different risk groups 

use bene_id from_dt prncpal_dgns_cd icd_dgns_cd* tavr savr icd_prcdr_cd* using "$datadir/all_InpatientCardiology.dta", clear 
do "$allcode/FRAC_ID_PTCA.do"
	gen tokeep = 0 
	forvalues i = 1/5 { 
		replace tokeep = 1 if inlist(icd_dgns_cd`i', "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(icd_dgns_cd`i', "3968", "3969", "3979", "4241") // ICD-9
		replace tokeep = 1 if inlist(substr(icd_dgns_cd`i',1,4), "I060", "I061", ///
			"I062", "I068", "I069", "I080", "I088", "I089") | ///
			inlist(icd_dgns_cd`i',"I350", "I351","I352") // ICD-10
	}
	rename tokeep as_flag
gen yq = qofd(from_dt) 
format yq %tq
gcollapse (max) savr tavr ptca as_flag, by(bene_id yq) fast
rename as_flag as_flag_surgery
gen year = floor(yq/4)+1960

forvalues y = 2010/2017 { 
	merge m:1 bene_id year using "$datadir/toappend_`y'.dta", nogenerate
}

// fill in to quarter level for those without surgeries
gen q = mod(yq, 4) + 1
expand 4 if missing(q) 
gsort bene_id year
replace q = mod(_n,4)+1 if missing(q)
replace yq =( year - 1960)*4 + (q-1) if missing(yq) 
format yq %tq 
drop if year < 2010 // some from earlier years was picked up in OP claims

replace as_flag = 0 if missing(as_flag) 
replace as_flag_ = 0 if missing(as_flag_)
replace as_flag = min(1, as_flag + as_flag_)
drop as_flag_
foreach v of var savr tavr ptca { 
	replace `v' = 0 if missing(`v') 
} 

compress
save "$datadir/all_SurgicalCandidates.dta", replace
}
 ********************************************************************************
