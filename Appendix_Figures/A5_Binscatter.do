/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

// total change in TAVR volume -- average over last year at CZ level 
gen newtavr = tavr if inrange(yq,228,231)
bys CZID: ereplace newtavr = total(newtavr)

// total change in all volume -- between last year and first? 
gen newpci = 1 if inrange(yq, 228, 231)
gen oldpci = 1 if inrange(yq, 200, 204)
bys CZID: ereplace newpci = total(newpci)
bys CZID: ereplace oldpci = total(oldpci)
gen pcidiff = newpci - oldpci
replace pcidiff = . if missing(newpci) | missing(oldpci)

gen allprocs = 1 
gcollapse (mean) t_adopt pcidiff newtavr (sum) allprocs, by(CZID yq) fast

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = mean(todrop) 
	drop if todrop >= 0.2
	drop todrop

gcollapse (mean) t_adopt pcidiff newtavr allprocs, by(CZID) fast
set scheme cblind1
binscatter  pcidiff newtavr if newtavr <= 200 [aw=allprocs], nq(100) linetype(qfit) ///
	xtitle("Average Change in TAVR Volume, CZ Level") ///
	ytitle("Average Change in Total Surgical Volume, CZ Level")
		// note: dropping outliers doesn't affect this much, just enhances visibility. 

// Save graphs
graph save "$output/Binscatter_TAVR_AllVolume.gph", replace
graph export "$output/Binscatter_TAVR_AllVolume.pdf", as(pdf) replace
********************************************************************************
