/*******************************************************************************
* Title: Identify individual-level data 
* Created by: Alex Hoagland
* Created on: 1/11/2022
* Last modified on: 4/2024
* Last modified by: 
* Purpose: 
	- 1. pulls all patients from 20% file with AS diagnosis
	- 2. assign geography + merge demographics
	- 3. identify surgeries/interventions from 100% inpatient file

* Notes: - requires at least one outpatient claim with AS as primary dx

* Key edits: 
*******************************************************************************/


***** 1. Pull from 20% outpatient
use bene_id bene_dob age sex race cnty_cd state_cd bene_zip file_year death_dt ///
	using /disk/aging/medicare/data/harm/20pct/bsf/2010/bsfab2010.dta
save "$datadir/ASpatients2024_20p.dta", replace

forvalues yr = 2011/2016 { 
	di "****** YEAR: `yr' *********"
	use bene_id bene_dob age sex race cnty_cd state_cd bene_zip file_year death_dt ///
	using /disk/aging/medicare/data/harm/20pct/bsf/`yr'/bsfab`yr'.dta
	append using "$datadir/ASpatients2024_20p.dta"
	save "$datadir/ASpatients2024_20p.dta", replace
}

use bene_id bene_dob age sex race cnty_cd state_cd zip_cd file_year death_dt ///
	using /disk/aging/medicare/data/harm/20pct/bsf/2017/bsfab2017.dta
rename zip_cd bene_zip 
append using "$datadir/ASpatients2024_20p.dta"
rename bene_zip zip_cd

// construct CZID and adoption date
gen ssacd = state_cd + cnty_cd // First, go from SSA state/county to FIPS
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
rename fipsc FIPS // Now go from FIPS to CZ
merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
rename Commuting CZID
drop ssacd FIPS state_cd cnty_cd zip_cd
drop if missing(CZID)

// now expand by 4 and add the yq 
expand 4
bys bene_id CZID file_year: gen q = _n
gen yq = qofd(mdy(q*3,1,file_year))
drop q 

compress
save "$datadir/ASpatients2024_20p.dta", replace

keep bene_id
duplicates drop 
save "$datadir/20p_flag.dta", replace // useful for merges later on 
********************************************************************************


***** 2. Match to inpatient (100%)
use "$datadir/IVCEventStudy_Base.dta", clear

// define procs of interest
gen cabg = inlist(icd91, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd92, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd93, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd94, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd95, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd96, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
replace cabg = 1 if inlist(icd97, "3610", "3611", "3612", "3613", "3614", "3615", "3616", "3617", "3619")
gen cath = inlist(icd91, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd92, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd93, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd94, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd95, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd96, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
replace cath = 1 if inlist(icd97, "3721", "3722", "3723", "8852", "8853", "8854", "8855", "8856", "8857")
gen ptcaonly = inlist("0066", icd91, icd92, icd93, icd94, icd95, icd96, icd97)

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

gcollapse (max) tavr savr ptcaonly cath cabg ptca2 (mean) t_adopt, by(bene_id yq CZID)
merge 1:1 bene_id yq CZID using "$datadir/ASpatients2024_20p.dta", keep(2 3) nogenerate
foreach v of var tavr savr ptcaonly ptca2 cath cabg { 
	replace `v' = 0 if missing(`v')
}
compress
save "$datadir/ASpatients2024_20p.dta", replace
********************************************************************************


***** Add in outpatient procedures 
// note: uses 0c_IDOutpatientProcedures_ByPhysicianType.do to identify these procedures
preserve // collapse to 0/1 per patient-yq for merging in 
use "$datadir/all_OutpatientCardiology.dta", clear 
gcollapse (max) tavr savr ptca2, by(bene_id yq) fast 
rename tavr o_tavr
rename savr o_savr
rename ptca2 o_ptca2
save "$datadir/tomerge.dta", replace
restore

merge 1:1 bene_id yq using "$datadir/tomerge.dta", keep(1 3) nogenerate
replace tavr = 1 if o_tavr == 1 
replace savr = 1 if o_savr == 1
replace ptca2 = 1 if o_ptca2 == 1
replace ptcaonly = 1 if o_ptca2 == 1
drop o_*
rm "$datadir/tomerge.dta"
********************************************************************************


***** collapse to rate/1000
// use "$datadir/ASpatients2024_20p.dta", clear
egen any = rowmax( tavr savr ptca2) 
egen tavrsavr = rowmax( tavr savr) 
egen cabgcathptca = rowmax( cabg cath ptcaonly) 
egen cabgcath = rowmax( cabg cath )
gcollapse (mean) any tavr savr tavrsavr ptcaonly cath cabg* ptca2 t_adopt, by(CZID yq) fast
foreach v of var any-ptca2 { 
	replace `v' = `v' * 1000 // change to rates
}

compress
save "$datadir/ASpatients2024_20p_collapsed_withoutpatient.dta", replace
********************************************************************************
