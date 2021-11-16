/*******************************************************************************
* Title: Effect of TAVR adoption on cardiologist provision of preventive care: 
	3 -- time between last screening and surgery
* Created by: Alex Hoagland
* Created on: 10/15/2021
* Last modified on: 10/15/2021
* Last modified by: 
* Purpose: Simple event study of TAVR adoption on preventive care visits 
* Notes: 

* Key edits: 
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
********************************************************************************


***** 1. Use panel from 1_EventStudy.do
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear

*** Keep only those who were screened and, ultimately, received surgery
// keep only those screened
gen prev = 0
replace prev = 1 if inlist(hcpcs_cd, "93303", "93304", "93306", "93307", "93308", "93320", "93325", "93350", "93351")
replace prev = 1 if substr(hcpcs_cd, 1, 4) == "C892" | hcpcs_cd == "C8930"
keep if prev == 1

// identify surgery dates
// preserve
// use "$datadir/all_as_ip", clear
// 	* Identify TAVR-procedures (only in first 10 procs)
// 	gen tavr = 0
// 	forvalues i = 1/10 { 
// 		replace tavr = 1 if inlist(icd_prcdr_cd`i', "3505", "3506")
// 		replace tavr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF3" // ICD-10
// 		replace tavr = 1 if icd_prcdr_cd`i' == "X2A5312" // extra ICD-10
// 	}
//	
// 	* Identify SAVR procedures (only in first 10 procs)
// 	gen savr = 0
// 	forvalues i = 1/10 { 
// 		replace savr = 1 if inlist(icd_prcdr_cd`i', "3521", "3522") // ICD-9
// 		replace savr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF0" // ICD-10
// 	}
// keep if tavr == 1 | savr == 1
// collapse (min) first_surg=from_dt, by(bene_id) fast
// compress
// save "$datadir/tomerge_surgeries.dta", replace
// restore

merge m:1 bene_id using "$datadir/tomerge_surgeries.dta", keep(3) nogenerate
drop if from_dt >= first_surg // ignore follow-up care for now

*** Identify time between last screening and surgery for each patient
keep npi year bene_id from_dt first_surg
duplicates drop
collapse (max) from_dt first_surg, by(npi bene_id) fast
gen year = year(first_surg)
gen spacetime = first - from
collapse (mean) spacetime, by(npi year) fast 

*** Merge in TAVR adoption date
merge m:1 npi using "$datadir/BaseEventStudy_20211020.dta", keep(1 3) nogenerate
compress
save "$datadir/EventStudy_20211020", replace
********************************************************************************


***** 3. Make sure all years are accounted for with cardiologists
// Seems like there are a scant few with missing years -- for now, replace them with 0s
use "$datadir/EventStudy_20211020.dta", clear
bysort npi: egen test1 = min(year)
bysort npi: egen test2 = max(year)
fillin npi year
drop if _fillin == 1 & year < test1
drop if _fillin == 1 & year > test2
replace spacetime = . if _fillin == 1
bysort npi: ereplace fyear_tavr = mean(fyear_tavr)
drop test* _fillin
save "$datadir/EventStudy_20211020.dta", replace
********************************************************************************


***** 4. Perform event study
local outcomes spacetime
foreach y of local outcomes { 
	use "$datadir/EventStudy_20211020.dta", clear
	qui gen treated = (!missing(fyear))
	qui gen period_yr = year - fyear if treated == 1

	*** Gen dummy variables
	qui sum period_yr
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yr == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yr == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	*** Store mean before treatment 
	sum `y' if period_yr < 0 | missing(period_yr), d

	*** Run regression 
	reghdfe `y' dummy*, absorb(npi year) 

	*** Graph results
	regsave
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)
	local obs = _N+1
	set obs `obs'
	replace y = -1 in `obs'
	replace coef = 0 in `obs'
	replace stderr = 0 in `obs'
	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr

	sort y 
	twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
		(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
		graphregion(color(white)) legend(off) ///
		xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
		xsc(r(-6(1)6)) xlab(-6(1)6) xtitle("Years Around TAVR Adoption") /// 
		ylab(,angle(horizontal))
	graph save "$mydir/ToExport_EventStudy_Screening-SurgeryGapLength.gph", replace
	graph export "$mydir/ToExport_EventStudy_Screening-SurgeryGapLength.pdf", as(pdf) replace
}
