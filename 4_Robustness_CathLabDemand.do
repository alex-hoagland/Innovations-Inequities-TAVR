/*******************************************************************************
* Title: Cath Lab Demand (robustness check)
* Created by: Alex Hoagland
* Created on: July 2024
* Last modified on: 7/2024
* Last modified by: 
* Purpose: 

* Notes: - identifies total CZ demand (at proc level) for cardiac cath labs around TAVR adoption

* Key edits: 
	 // note: tried to use MEDPAR file which has a cardiac cath spending amount, 
	 but do not have MEDPAR in this DUA
********************************************************************************/


***** 0. Pull all cardiac catheterization procedures based on revenue center claims
cap confirm file "$datadir/CathLabDemand.dta"
if (_rc == 0) {
	use "$datadir/CathLabDemand.dta", clear
}
else { 
	clear
	gen bene_id = ""
	save "$datadir/CathLabProcs.dta"
	
	forvalues yr = 2010/2017 { 
	di "YEAR: `yr'"
	use /disk/aging/medicare/data/harm/100pct/ip/`yr'/ipr`yr'.dta if rev_cntr == "0481", clear
	
	* Combine and save
	append using "$datadir/CathLabProcs.dta"
	save "$datadir/CathLabProcs.dta", replace
	}
	
	duplicates drop
	compress
	save "$datadir/CathLabProcs.dta", replace

	// collapse to unique beneficiary-lab-date observations 
	use "$datadir/CathLabProcs.dta", clear
	keep bene_id thru_dt rev_dt rev_unit rev_chrg file_year 
	gcollapse (sum) rev_unit rev_chrg, by(bene_id thru_dt rev_dt file_year) fast
	replace rev_unit = 50 if rev_unit >= 50 // top-code 0.1%
	replace rev_chrg = 100000 if rev_chrg >= 100000 // topcode 0.1%
	gen ssacd = ""
	gen zip = ""
	forvalues yr = 2010/2016 { 
		di "***** YEAR: `yr' *****"
		merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsf/`yr'/bsfab`yr'.dta, ///
			keepusing(bene_id file_year cnty_cd state_cd bene_zip) ///
			keep(1 3) nogenerate
		replace ssacd = state_cd + cnty_cd if missing(ssacd)
		replace zip = bene_zip if missing(zip)
		drop cnty_cd state_cd bene_zip
	}
	gen g_fileyear = file_year
	merge m:1 bene_id g_fileyear using /disk/aging/medicare/data/harm/100pct/bsf/2017/bsfab2017.dta, ///
			keepusing(bene_id g_fileyear cnty_cd state_cd bene_zip) ///
			keep(1 3) nogenerate
	replace ssacd = state_cd + cnty_cd if missing(ssacd)
	replace zip = bene_zip if missing(zip)
	drop cnty_cd state_cd bene_zip

	// construct CZID and adoption date
	// First, go from SSA state/county to FIPS
	merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
	rename fipsc FIPS // Now go from FIPS to CZ
	merge m:1 FIPS using "$geodata/CZs_Crosswalk", keep(1 3) keepusing(CommutingZoneID2000) nogenerate
	rename Commuting CZID
	drop ssacd FIPS 
	drop if missing(CZID)
	gen yq = qofd(thru_dt)
	replace yq = qofd(rev_dt) if missing(thru_dt)

	gcollapse (sum) rev_unit rev_chrg, by(CZID bene_id yq) fast
	gen numpats = 1
	gcollapse (sum) rev_unit rev_chrg numpats, by(CZID yq) fast
	 fillin CZID yq
	 replace rev_unit = 0 if missing(rev_unit)
	 replace numpats = 0 if missing(numpats) 
	 replace rev_chrg = 0 if missing(rev_chrg)
	 drop _fillin
	 rename numpats cathlab_pats
	 rename rev_unit cathlab_unit
	 rename rev_chrg cathlab_charges
	 
	 gen year = yofd(dofq(yq))
	 do $allcode/Inflation.do "cathlab_charges"
	 drop year
	compress
	save "$datadir/CathLabDemand.dta", replace
}
********************************************************************************


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

local figname = "EventStudy_CZLevel_CathLabDemand_`1'"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

gen allprocs = 1
gcollapse (sum) allprocs (mean) t_adopt, by(CZID yq) fast
merge 1:1 CZID yq using "$datadir/CathLabDemand.dta", keep(3) nogenerate
replace cathlab_unit_t = 2000 if cathlab_unit_t > 2000 // topcode at the CZ level 
gen outcome = `1'

// Require that a CZID have sufficient procs in each quarter (deals with 0s as well)
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace outcome = 0 if missing(outcome)
// 	replace todrop = 1 if allprocs < 10
// 	bysort CZID: ereplace todrop = mean(allprocs) 
// 	drop if todrop < 4
// 	drop todrop

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// DD regression -- done in lpdid as pooled effects

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
// local pretreat = round(r(mean), .1)
local pretreat: di %9.0fc `r(p50)'

// Run regression 
gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
replace outcome = log(outcome) // only for spending
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12) pmd(12) post_pooled(12)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(0.25 2 "Pre-treatment median: $`pretreat'", place(e)) ///
	text(.05 -9 "Pooled Effect: `pooledfx'", place(s))
	// text(`pooledfx' -9 "Pooled Effect: `pooledfx'", place(s))
	
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************

