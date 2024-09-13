/*******************************************************************************
* Title: Estimate patient risk / appropriateness for TAVR
* Created by: Alex Hoagland
* Created on: 2/21/2022
* Last modified on: 2/7/2023
* Last modified by: 
* Purpose: Identifies risk/appropriateness for TAVR
* Notes: - identifies a risk measure for each patient-year for all AS, OP, and IP patients
	 - uses STS-PROM model predicting risk of surgical mortality following TAVR/SAVR

* Key edits: 
*******************************************************************************/


***** 1. Use all cardiology patients (not just inpatient; can trim this down later)
use bene_id using  "$datadir/all_SurgicalCandidates.dta", clear
duplicates drop
// about 11.5 million patients

sort bene_id 
save "$datadir/AllPatients_BeneIDs.dta", replace
********************************************************************************


***** 2. Match in major beneficiary information (risk scores, chronic conditions, etc.)
clear
gen year = .
save "$datadir/PatientRisk.dta", replace

// Merge in dummies for chronic conditions and # of hospitalizations in each year
forvalues i = 2015/2017 { 
	di "YEAR: `i'"
	use "$datadir/AllPatients_BeneIDs.dta", clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcc/`i'/bsfcc`i'.dta, keep(3) nogenerate // chronic conditions
	gen num_cc = 0 
	foreach v of varlist *e { // loop through all "first ever" variables
		di "Variable `v'"
		replace num_cc = num_cc + 1 if !missing(`v') 
	}
	keep bene_id num_cc amie chfe diabtese hypert_ever strktiae copde
	
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcu/`i'/bsfcu`i'.dta, ///
		keep(3 ) nogenerate ///
		keepusing(bene_id *er_vi* acute_st* oip_st* ///
			readmiss* acute_co* oip_co*) 
	gen year = `i'
	append using "$datadir/PatientRisk.dta"
	save "$datadir/PatientRisk.dta", replace
}

// Merge in age/sex information
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	use "$datadir/PatientRisk.dta" if year == `i', clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfab/`i'/bsfab`i'.dta, ///
		keep(3) nogenerate ///
 		keepusing(age sex state_cd cnty_cd race death_dt) 
	save "$datadir/PatientRisk_`i'.dta", replace
}

use "$datadir/PatientRisk_2010.dta", clear
forvalues i = 2011/2017 { 
	append using "$datadir/PatientRisk_`i'"
}
save "$datadir/PatientRisk.dta", replace
forvalues y = 2010/2017 {
	rm "$datadir/PatientRisk_`y'.dta"
}

// dual status comes from bsfd files (at least until 2015) 
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	use "$datadir/PatientRisk.dta" if year == `i', clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfd/`i'/bsfd`i'.dta, ///
		keep(3) nogenerate ///
		keepusing(bene_id dual_*) 
	save "$datadir/PatientRisk_`i'.dta", replace
}

use "$datadir/PatientRisk_2010.dta", clear
forvalues i = 2011/2017 { 
	append using "$datadir/PatientRisk_`i'"
}
compress
save "$datadir/PatientRisk.dta", replace
forvalues y = 2010/2017 { 
	rm "$datadir/PatientRisk_`y'.dta"
}

// Merge in income data using patient location data. 
// Merge in income information (and ADI at the 5-digit zip code) 
gen ssacd = state_cd + cnty_cd
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
rename fipsc fips_string
merge m:1 fips_string year using "$mydir/2_Data/Income/fips_income.dta", keep(3) nogenerate
	// 0.30%(49 counties) are missing county assignment as they are missing counties in MSBF file
save "$datadir/PatientRisk.dta" , replace

// to pull in ADI, need zip code information 
forvalues i = 2010/2017 { 
	di "YEAR: `i'"
	use "$datadir/PatientRisk.dta" if year == `i', clear
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfab/`i'/bsfab`i'.dta, ///
		keep(3) nogenerate ///
 		keepusing(bene_id *zip*)
	save "$datadir/PatientRisk_`i'.dta", replace
}

use "$datadir/PatientRisk_2010.dta", clear
forvalues i = 2011/2017 { 
	append using "$datadir/PatientRisk_`i'"
}
save "$datadir/PatientRisk.dta", replace
forvalues y = 2010/2017 {
	rm "$datadir/PatientRisk_`y'.dta"
}
use "$datadir/PatientRisk", clear
gen zip_cd = zip5
destring zip_cd, replace
merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_allstates.dta", keep(1 3) nogenerate // 5-digit zip
rename adi riskvar_adi_5
drop zip_cd
destring zip9, gen(zip_cd)
merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_9digits.dta", keep(1 3) nogenerate // 9-digit zip
drop adi_state zip_cd
rename adi riskvar_adi_9 
compress
save "$datadir/PatientRisk.dta", replace
********************************************************************************


***** 3. Variables used in calculating STS-PROM
use "$datadir/PatientRisk.dta", clear

// Panel A: Demographics
// age, sex, black, hispanic, other race, log(income), dual (any and full), ADI (5- and 9-digit)
gen riskvar_fem = (sex == "2")
rename age riskvar_age
gen riskvar_black = (race == "2") 
gen riskvar_hisp = (race == "5")
gen riskvar_othernonwhite = inlist(race,"0","3","4","6") 
drop sex race 
bysort bene_id: ereplace death_dt = min(death_dt) 
destring medinc_hh, replace
gen riskvar_income = log(medinc_hh)
gen riskvar_dual_any =(dual_mo > 0) 
gen riskvar_dual_full = (dual_mo == 12) 
drop medinc_hh 

// merge into SurgicalCandidates data first to do rest of vars at quarterly level 
merge 1:m bene_id year using "$datadir/all_SurgicalCandidates", keep(2 3) nogenerate

// Panel B: Chronic conditions (pre-existing at start of quarter)
gen startdt = mdy(q*3-2,1,year)
rename num_cc riskvar_numcc
foreach v of varlist amie copde chfe diabtese strktiae hypert_ever { 
	gen riskvar_cc_`v' = 0
	replace riskvar_cc_`v' = 1 if !missing(`v') & `v' < startdt
}
drop amie chfe copde hypert_ever diabt strk

// Panel C: Previous surgeries
gsort bene_id yq
by bene_id (yq) : gen riskvar_prevptca = sum(ptca) 
by bene_id (yq): gen riskvar_prevsavr = sum(savr)
by bene_id (yq): gen riskvar_prevtavr = sum(tavr)
replace riskvar_prevptca = riskvar_prevptca - 1 if ptca == 1 // don't count current quarters' surgeries
replace riskvar_prevsavr = riskvar_prevsavr - 1 if savr == 1 // don't count current quarters' surgeries
replace riskvar_prevtavr = riskvar_prevtavr - 1 if tavr == 1 // don't count current quarters' surgeries
gen riskvar_prev_numsurgeries = riskvar_prevptca + riskvar_prevsavr + riskvar_prevtavr
gen riskvar_prev_anysurgeries =(riskvar_prev_numsurgeries > 0 )
foreach v of var riskvar_prevtavr riskvar_prevsavr riskvar_prevptca { 
	replace `v' = 1 if `v' > 1  
}

// Panel D: Within year utilization (should this be lagged by a year?) 
gen riskvar_ed_num = 0 
foreach v of varlist *_er_* { 
	replace riskvar_ed_num = riskvar_ed_num + `v' if !missing(`v')
}
gen riskvar_ed_any = (riskvar_ed_num > 0)
drop *_er_*

gen riskvar_stay_num = 0 
foreach v of varlist acute_st acute_stays oip_stay oip_stays { 
	replace riskvar_stay_num = riskvar_stay_num + `v' if !missing(`v')
}
gen riskvar_stay_any = (riskvar_stay_num > 0)
drop acute_st* oip_st*

gen riskvar_days_num = 0 
foreach v of varlist acute_co* oip_co* { 
	replace riskvar_days_num = riskvar_days_num + `v' if !missing(`v')
}
gen riskvar_days_any = (riskvar_days_num > 0)
drop acute_co* oip_co*

rename readmissions riskvar_readmissions
replace riskvar_readmissions = 0 if missing(riskvar_readmissions)
replace riskvar_readmissions = riskvar_readmissions + readmiss if !missing(readmiss) 
drop readmiss

// Panel E: Fixed effects
// Create local-market information (for clustering) 
*** First, go from SSA state/county to FIPS
// gen ssacd = state_cd + cnty_cd
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate

*** Now go from FIPS to CZ
rename fipsc FIPS
merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
rename Commuting CZID // 0.19% of observations (979) missing CZID
 
gsort bene_id year yq
order bene_id year yq
order riskvar_* , last

xtset CZID
destring riskvar_adi_9, replace force
replace riskvar_adi_9 = riskvar_adi_5 if missing(riskvar_adi_9)

compress
save "$datadir/all_SurgicalCandidates.dta", replace
// rm "$datadir/PatientRisk.dta"
********************************************************************************
