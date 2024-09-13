/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Prices for TAVR and SAVR 
* Created by: Alex Hoagland
* Created on: 7/30/2024
* Last modified on: 
* Last modified by: 
* Purpose: Time Series + LPDID

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Descriptive graph 
set scheme cblind1 

clear
gen bene_id = ""
save "$datadir/allrev.dta", replace

// identify all relevant procs by DRG in inpatient files 
forvalues y = 2010/2017 {
	di "***** YEAR: `y' ******"
	use /disk/aging/medicare/data/harm/100pct/ip/`y'/ipc`y'.dta ///
		if inlist(substr(drg_cd,1,1), "2", "3"), clear
	destring drg_cd, replace
	keep if inrange(drg_cd, 216,221) | /// cardiac cath
		inrange(drg_cd, 231,236) | /// bypass
		inrange(drg_cd, 246,249) | /// stent
		inrange(drg_cd, 250,251) | /// PCI1
		inrange(drg_cd, 273,274) | /// PCI2 
		inrange(drg_cd, 266, 267) | /// SAVR and TAVR 
		inlist(drg_cd, 268, 269, 319, 320) // other
	cap drop *_e_* *_vrsn_* *_poa_*
	append using "$datadir/allrev.dta"
	save "$datadir/allrev.dta", replace
}

// within DRGs for SAVR and TAVR, need to split
gen savr = 0
	forvalues i = 1/10 { 
		replace savr = 1 if inlist(icd_prcdr_cd`i', "3521", "3522") // ICD-9
		replace savr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF0" // ICD-10
	}
gen tavr = 0
	forvalues i = 1/10 { 
		replace tavr = 1 if inlist(icd_prcdr_cd`i', "3505", "3506")
		replace tavr = 1 if substr(icd_prcdr_cd`i',1,5) == "02RF3" // ICD-10
		replace tavr = 1 if icd_prcdr_cd`i' == "X2A5312" // extra ICD-10
	}
	
// Inflation adjust prices 
rename file_year year 
do /homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/3_SourceCode/Inflation.do "pmt_amt"
drop if missing(pmt_amt)
replace pmt_amt = 100000 if pmt_amt >= 100000 // topcode ~1%
duplicates drop

compress
save "$datadir/allrev.dta", replace

// calculate average payments by drg-year, except for TAVR and SAVR
use "$datadir/allrev.dta", clear
drop if tavr == 1 & savr == 1
replace drg_cd = . if tavr == 1 | savr == 1
replace drg_cd = 216 if inrange(drg_cd, 216,221) // cardiac cath
replace drg_cd = 231 if inrange(drg_cd, 231,236) // bypass
replace drg_cd = 246 if inrange(drg_cd, 246,249) // stent
replace drg_cd = 266 if inrange(drg_cd, 266,269) | drg_cd == 319 | drg_cd == 320 // aortic procs
replace drg_cd = 250 if inlist(drg_cd, 250,251,273,274) // pci
gcollapse (mean) pmt_amt (sd) sd=pmt_amt (count) n=pmt_, by(drg_cd tavr savr year) fast
gen lb = pmt_amt-1.96*sd/sqrt(n)
gen ub = pmt_amt + 1.96*sd/sqrt(n)

twoway (connect pmt_amt year if savr == 1) (connect pmt_amt year if tavr == 1) ///
	(connect pmt_amt year if drg == 216) (connect pmt_amt year if drg == 231) ///
	(connect pmt_amt year if drg == 246) (connect pmt_amt year if drg == 250) ///
	(rcap lb ub year if drg == 250, color(gs10)) ///
	(rcap lb ub year if drg == 216, color(gs10)) (rcap lb ub year if drg == 231, color(gs10)) ///
	(rcap lb ub year if drg == 246, color(gs10)) ///
	(rcap lb ub year if savr == 1, color(gs10)) (rcap lb ub year if tavr == 1, color(gs10)), ///
	xtitle("Year") ytitle("") ///
	legend(order(1 "SAVR" 2 "TAVR" 3 "Cardiac Cath" 4 "Bypass" 5 "Stent" 6 "PCI" )) ///
	xline(2011.9, lpattern(dash) lcolor(black)) ///
	xsc(r(2010(1)2017)) xlab(2010(1)2017) ylab(,format(%9.0fc))
graph save "$output/AllPrices.gph", replace
graph export "$output/AllPrices.pdf", as(pdf) replace
********************************************************************************
