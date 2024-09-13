/*******************************************************************************
* Title: Binned Risk Event Study
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess which patient risk groups lost access to treatments 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
if ("`2'" != "all" & "`2'" != "perc") { // if you want a specific regression
	use "$datadir/IVCEventStudy_Base.dta", clear
	gen test = inrange(predrisk_90, `2', `3')
	qui sum test // # of patients with this risk 
	local wt = `r(mean)'

	local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
	local figname = "EventStudy_CZLevel_`1'Treatments_Binned"

	*** Identify treatment (first adoption of tavr) 
	// cap drop t_adopt
	// gen t_adopt = yq if tavr == 1
	// bysort CZID: ereplace t_adopt = min(t_adopt)

	drop if missing(predrisk_90)

	if ("`treatment'" == "high") { 
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (tavr == 1 | savr == 1)
		gen outcome1 = (num_procs == 1 & inrange(predrisk_90,`2',`3'))
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}
	else if ("`treatment'" == "low") {
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (ptca2 == 1)
		gen outcome1 = (num_procs == 1 & inrange(predrisk_90,`2',`3'))
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}
	else if ("`treatment'" == "all") {
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (tavr == 1 | savr == 1 | ptca2 == 1)
		gen outcome1 = (num_procs == 1 & inrange(predrisk_90,`2',`3'))
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}

	// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = max(todrop) 
	drop if todrop == 1 
	drop todrop

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1
	qui gen post = (period_yq >= 0 & !missing(period_yq))

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	qui reghdfe outcome dummy*, absorb(CZID yq) vce(cluster CZID) 
	regsave , pval // keep p-values for multiple hypothesis testing
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)

	gen lb = coef - 1.96*stderr
	gen ub = coef + 1.96*stderr

	// keep only 4 yqs pre-/post-adoption
	drop if abs(y) > 12
	drop if y < 0 
	gcollapse (mean) coef lb ub p, fast
	gen r_lb = `2'
	gen wt = `wt'*1000
	save "$datadir/binned_`1'_`2'.dta", replace
}
********************************************************************************


***** 2. Combine 
if ("`2'" == "all") { // combine figures
	local 1 = "all"
	local allfiles: dir "$datadir/" files "binned_`1'_*"
	clear
	gen var = ""
	foreach f of local allfiles { 
		append using "$datadir/`f'"
	}
	cap drop if missing(wt)
	
	gen se = (coef - lb)/1.96
	gen t = coef/se
	gen p = (1-normal(abs(t))) // one-sided p-values
	di "***** COPY THESE TO PASTE INTO DATA EDITOR BELOW *****"
	list p 
	// make sure you have copied the list of p-values here to make sharpened q-values
	preserve
	clear
	do "$allcode/fdr_sharpened_qvalues.do" // need to paste them into data editor, then continue
	keep b p 
	rename b qval
	rename pval p 
	tempfile tomerge
	save `tomerge', replace
	restore
	
	merge 1:1 p using `tomerge.dta', keep(3) nogenerate
	gen newt = invnormal(1-qval) 
	gen newse = abs(coef/newt)
	gen newlb = coef - newse*1.96
	gen newub = coef + newse*1.96
	
	drop if r_lb < .0075
	twoway (scatter coef r_lb, color(maroon)) (rcap newlb newub r_lb, color(gs12)) , ///
		graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
		legend(off) xtitle("Patient 90-Day Risk") ///
		ysc(r(-1.5(.5)1.5)) ylab(-1.5(.5)1.5) ylab(,angle(horizontal))
	graph save "$output/MarketLevel_ByRisk90_`1'", replace
	graph export "$output/MarketLevel_ByRisk90_`1'.pdf", replace as(pdf) 
	
	expand wt, gen(newv) 
	gen coef2 = coef if newv == 0 // original coefs only 
	local b = .2
	twoway (scatter coef2 r_lb, color(maroon%60))  ///
		(lowess coef r_lb, bwidth(`b') color(maroon)) ///
		(lowess newub r_lb, bwidth(`b') color(gs12)) ///
		(lowess newlb r_lb, bwidth(`b') color(gs12)) , ///
		graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
		legend(off) xtitle("Patient 90-Day Risk") ylab(,angle(horizontal)) ///
		xline(0.03, lcolor(black)) xline(0.08, lcolor(black)) 
	graph save "$output/MarketLevel_ByRisk90_`1'Smoothed", replace
	graph export "$output/MarketLevel_ByRisk90_`1'Smoothed.pdf", replace as(pdf) 
}

if ("`2'" == "perc") { // combine figures in % terms
	// first, run for full sample (to get denominator)
	use "$datadir/IVCEventStudy_Base.dta", clear
	local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
	drop if missing(predrisk_90)

	if ("`treatment'" == "high") { 
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (tavr == 1 | savr == 1)
		gen outcome1 = (num_procs == 1)
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}
	else if ("`treatment'" == "low") {
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (ptca2 == 1)
		gen outcome1 = (num_procs == 1)
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}
	else if ("`treatment'" == "all") {
		// Construct outcome: aggregate count of procedure at surgeon-yq level
		gen num_procs = (tavr == 1 | savr == 1 | ptca2 == 1)
		gen outcome1 = (num_procs == 1 )
		gen allprocs = 1
		gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
	}

	// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = max(todrop) 
	drop if todrop == 1 
	drop todrop

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yq = yq -  t_adopt if treated == 1
	qui gen post = (period_yq >= 0 & !missing(period_yq))

	*** Gen dummy variables
	qui sum period_yq
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	qui reghdfe outcome dummy*, absorb(CZID yq) vce(cluster CZID) 
	regsave , pval // keep p-values for multiple hypothesis testing
	drop if strpos(var,"o.")
	keep if strpos(var, "dummy")
	gen y = substr(var, 11, .)
	destring y, replace
	replace y = y * -1
	replace y = real(substr(var, 7, .)) if missing(y)

	// keep only 4 yqs pre-/post-adoption
	drop if abs(y) > 12
	drop if y < 0 
	gcollapse (mean) coef, fast
	replace coef = abs(coef)
	local mydenom = coef[1]

	local 1 = "all"
	local allfiles: dir "$datadir/" files "binned_`1'_*"
	clear
	gen var = ""
	foreach f of local allfiles { 
		append using "$datadir/`f'"
	}
	cap drop if missing(wt)
	
	gen se = (coef - lb)/1.96
	gen t = coef/se
	gen p = (1-normal(abs(t))) // one-sided p-values
	di "***** COPY THESE TO PASTE INTO DATA EDITOR BELOW *****"
	list p 
	// make sure you have copied the list of p-values here to make sharpened q-values
	preserve
	clear
	do "$allcode/fdr_sharpened_qvalues.do" // need to paste them into data editor, then continue
	keep b p 
	rename b qval
	rename pval p 
	tempfile tomerge
	save `tomerge', replace
	restore
	
	merge 1:1 p using `tomerge.dta', keep(3) nogenerate
	gen newt = invnormal(1-qval) 
	gen newse = abs(coef/newt)
	gen newlb = coef - newse*1.96
	gen newub = coef + newse*1.96
	
	// now normalize by the denominator
	foreach v of var coef newlb newub {
		replace `v' = `v' / `mydenom' * 100
	} 
	
	drop if r_lb < .01
	twoway (scatter coef r_lb, color(maroon)) (rcap newlb newub r_lb, color(gs12)) , ///
		graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
		legend(off) xtitle("Patient 90-Day Risk") ///
		ysc(r(-1.5(.5)1.5)) ylab(-1.5(.5)1.5) ylab(,angle(horizontal))
	graph save "$output/MarketLevel_ByRisk90_`1'", replace
	graph export "$output/MarketLevel_ByRisk90_`1'.pdf", replace as(pdf) 
	
	expand wt, gen(newv) 
	gen coef2 = coef if newv == 0 // original coefs only 
	local b = .2
	twoway (scatter coef2 r_lb, color(maroon%60))  ///
		(lowess coef r_lb, bwidth(`b') color(maroon)) ///
		(lowess newub r_lb, bwidth(`b') color(gs12)) ///
		(lowess newlb r_lb, bwidth(`b') color(gs12)) , ///
		graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
		legend(off) xtitle("Patient 90-Day Risk") ylab(,angle(horizontal)) ///
		xline(0.03, lcolor(black)) xline(0.08, lcolor(black)) 
	graph save "$output/MarketLevel_ByRisk90_`1'Smoothed_PERCENTAGE", replace
	graph export "$output/MarketLevel_ByRisk90_`1'Smoothed_PERCENTAGE.pdf", replace as(pdf) 
}
********************************************************************************
