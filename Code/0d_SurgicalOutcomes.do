/*******************************************************************************
* Title :Merge in surgical outcomes for all surgeries in inpatient data
* Created by: Alex Hoagland
* Created on: 1/11/2023
* Last modified on: 3/2023
* Last modified by: 
* Purpose: identifies all surgical mortality + readmissions (within 90 days) 

* Notes: - uses files created in earlier code + outpatient files

* Key edits: --
*******************************************************************************/


***** 1. Start with universe of surgeries, keep TAVR/SAVR/PCI diagnosis codes  
use bene_id from_dt file_year tavr savr icd_prcdr_cd* using "$datadir/all_InpatientCardiology.dta", clear 
do "$allcode/FRAC_ID_PTCA.do"
keep if tavr == 1 | savr == 1 | ptca == 1
drop icd*
duplicates drop
gcollapse (max) tavr savr ptca, by(bene_id file_year from_dt) fast
rename from_dt surg_dt
compress
save "$datadir/tomerge_surgicaloutcomes.dta", replace

// first, look at readmissions
forvalues i = 2010/2017 { 
	di "YEAR: `i'" 
	local j = `i' - 1
	use bene_id surg_dt file_year using "$datadir/tomerge_surgicaloutcomes.dta" /// 
		if inrange( file_year, `j', `i') , clear
	drop file_year
	bysort bene_id (surg_dt): gen n = _n
	reshape wide surg_dt, i(bene_id) j(n)
	merge 1:m bene_id using /disk/aging/medicare/data/harm/100pct/ip/`i'/ipc`i'.dta, ///
		keep(3) keepusing(bene_id from_dt thru_dt) nogenerate
	bysort bene_id from_dt thru_dt: gen i = _n 
	reshape long surg_dt, i(bene_id from_dt thru_dt i ) j(j) 
	gen test = thru_dt if from_dt == surg_dt 
	bysort bene_id surg_dt: ereplace test = max(test) 
	drop if missing(surg_dt) | surg_dt >= from_dt | from_dt <= test
	keep if inrange(from_dt - surg_dt, 1, 90) 
	gen days_readmit = (from_dt - surg_dt)
	keep bene_id surg_dt days_readmit 
	gcollapse (min) days_readmit, by(bene_id surg_dt) fast
	compress
	save "$datadir/tomerge_`i'.dta", replace
}

// add back to main data
use "$datadir/tomerge_2010.dta", clear
forvalues y = 2011/2017 { 
	append using "$datadir/tomerge_`y'.dta"
} 
gcollapse (min) days_readmit, by(bene_id surg_dt) fast
merge 1:m bene_id surg_dt using "$datadir/tomerge_surgicaloutcomes.dta", ///
	keep(2 3) nogenerate
compress
save "$datadir/tomerge_surgicaloutcomes.dta", replace
	
// second, mortality
forvalues i = 2010/2017 { 
	di "***** YEAR: `i' ********"
	use bene_id using "$datadir/tomerge_surgicaloutcomes.dta", clear 
	duplicates drop
	merge 1:m bene_id using /disk/aging/medicare/data/harm/100pct/bsf/`i'/bsfab`i'.dta, ///
		keep(3) keepusing(bene_id death_dt) nogenerate
	drop if missing(death_dt)
	duplicates drop 
	save "$datadir/tomerge_`i'", replace
}

// add back to main data
use "$datadir/tomerge_2010.dta", clear
forvalues y = 2011/2017 { 
	append using "$datadir/tomerge_`y'.dta"
} 
gcollapse (min) death_dt, by(bene_id) fast
merge 1:m bene_id using "$datadir/tomerge_surgicaloutcomes.dta", ///
	keep(2 3) nogenerate
gen days_mortality = death_dt - surg_dt + 1 if !missing(death_dt)
replace days_mortality = . if days_mortality > 90 
replace days_mortality = . if days_mortality < 0 // only 30 or so of these weird cases
drop death_dt
compress
save "$datadir/tomerge_surgicaloutcomes.dta", replace

// add main data to inpatient + surgical candidate files
rename surg_dt from_dt 
drop tavr savr file_year
merge 1:m bene_id from_dt using "$datadir/all_InpatientCardiology.dta", keep(2 3) nogenerate
rename from_dt surg_dt
replace ptca = 0 if missing(ptca) // lets you not have to id it each time in future 
compress
save "$datadir/all_InpatientCardiology.dta", replace

use "$datadir/tomerge_surgicaloutcomes.dta", clear
drop if missing(days_mortality) & missing(days_re)
rename surg_dt from_dt
drop tavr savr ptca file_year 
gen yq = qofd(from_dt) 
format yq %tq
gcollapse (min) days*, by(bene_id yq) fast
gen year = floor(yq/4)+1960
merge 1:1 bene_id yq using "$datadir/all_SurgicalCandidates.dta", keep(2 3) nogenerate
compress
save "$datadir/all_SurgicalCandidates.dta", replace

// clean up files 
forvalues y = 2010/2017 { 
	rm "$datadir/tomerge_`y'.dta"
}

rm "$datadir/tomerge_surgicaloutcomes.dta" // don't keep intermediate data sets
 ********************************************************************************
