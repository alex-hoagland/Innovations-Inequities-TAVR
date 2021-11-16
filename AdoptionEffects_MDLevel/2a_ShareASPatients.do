/*******************************************************************************
* Title: Effect of TAVR adoption on cardiologist provision of preventive care: 
	2a -- effect on provider focus on AS patients
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


***** 1. Construct new panel for all (including more than just AS) visits for each cardiologist
*** Carrier claims
use "$datadir/TreatmentPanel_AllCardiologist_OutpatientVisits_202110.dta", clear
keep npi 
duplicates drop
save "$datadir/tomerge_npi.dta", replace

use "$datadir/weird2016.dta", clear // 2016 was too big to read into memory, had to build manually
rename npi prf_npi
keep bene_id clm_id line_num thru_dt prf_npi prgrpnpi ///
	prv_type prvstate provzip hcfaspcl tax_num ///
 	line_icd* hcpcs_cd prtcptg  
save "$datadir/TreatmentPanel_AllCardiologist_ALLOutpatientVisits_20210.dta", replace

forvalues y = 2010/2015 {
	di "YEAR = `y'"
	use "$datadir/tomerge_npi.dta", clear
	rename npi prf_npi
	merge 1:m prf_npi using /disk/aging/medicare/data/harm/20pct/car/`y'/carl`y'.dta, keep(3) nogenerate
		
 	keep bene_id clm_id line_num thru_dt prf_npi prgrpnpi ///
 	    prv_type prvstate provzip hcfaspcl tax_num ///
 	    line_icd* hcpcs_cd prtcptg  
	    
	gen year = `y'
	gen aorticstenosis = 0 
	replace aorticstenosis = 1 if inlist(line_icd_dgns_cd, "3950", "3951", "3952", "3959", ///
		"3960", "3961", "3962", "3963") | ///
		inlist(line_icd_dgns_cd, "3968", "3969", "3979", "4241") // ICD-9
	replace aorticstenosis = 1 if inlist(substr(line_icd_dgns_cd,1,4), "I060", "I061", ///
		"I062", "I068", "I069", "I080", "I088", "I089") | ///
		inlist(line_icd_dgns_cd,"I350", "I351","I352") // ICD-10
	
	// collapse (max) aorticstenosis, by(bene_id prf_npi year clm_id thru_dt) fast // collapse to visit level
	compress
	
	append using "$datadir/TreatmentPanel_AllCardiologist_ALLOutpatientVisits_20210.dta"
	save "$datadir/TreatmentPanel_AllCardiologist_ALLOutpatientVisits_20210.dta", replace
}
********************************************************************************


***** 2. Percent of visits with an AS diagnosis
use "$datadir/TreatmentPanel_AllCardiologist_ALLOutpatientVisits_20210.dta", clear
collapse (max) aorticstenosis, by(bene_id prf_npi year clm_id thru_dt) fast // collapse to visit level
rename prf_npi npi
collapse (mean) aorticstenosis, by(npi year) fast
replace aorticstenosis = aorticstenosis * 100 // measure in percentages

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
replace aorticstenosis = 0 if _fillin == 1
bysort npi: ereplace fyear_tavr = mean(fyear_tavr)
drop test* _fillin
save "$datadir/EventStudy_20211020.dta", replace
********************************************************************************


***** 4. Perform event study
local outcomes aorticstenosis
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
	graph save "$mydir/ToExport_EventStudy_PercentAS.gph", replace
	graph export "$mydir/ToExport_EventStudy_PercentAS.pdf", as(pdf) replace
}
