/*******************************************************************************
* Title: Effect of TAVR Adoption on SAVR/TAVR or PCI use by income 
* Created by: Alex Hoagland
* Created on: 3/1/2022
* Last modified on: 
* Last modified by: 
* Purpose: Show inequities in access to surgeries by income quintile

* Notes: 

* Key edits:
*******************************************************************************/


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
global output "$mydir/ToExport/Inequities"
********************************************************************************


***** 1. Prep Data
use "$datadir/IVCEventStudy_Base.dta" if year < 2016, clear
drop if year == 2016 // why is 2016 a weird year? 
********************************************************************************


***** 2. Event Studies for Use of Interventions
local het = "income" // "income" or "race"
local surgeryout = "all" // "all" for TAVR/SAVR, "pci" for only PCI
local thetabar_l = .05
local thetabar_u = .10 
if ("`het'" == "income") { 
	// here loops through 5 quintiles of income 
	forvalues q = 1/5 { 
		preserve
		// keep if incq == 1 & predicted_risk > .05 // keep those in lowest income quintile, in crowd-out region

		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt)

		// Construct outcome: aggregate count of alternate procedure at surgeon-year level
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
					inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
					
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		replace num_procs = 0 if incq != `q' | !inrange(predicted_risk,`thetabar_l',`thetabar_u') // only look at share for low-income, crowd-out region patients.

		gen allprocs = 1
		collapse (sum) num_procs allprocs (mean) t_adopt, by(at_npi year) fast
		gen outcome = num_procs / allprocs * 100
		gen todrop = (allprocs < 10) // drop those with fewest procs
		bysort at_npi year: ereplace todrop = max(todrop)
		drop if todrop == 1

		do "$mydir/3_SourceCode/5_CrowdOut_Decomposition/4a_EventStudyFrag.do"

		// Save graphs
		graph save "$output/Inequities_Income_Quintile`q'_Intervention`surgeryout'.gph", replace
		graph export "$output/Inequities_Income_Quintile`q'_Intervention`surgeryout'", as(pdf) replace
		restore
	}
}
else if ("`het'" == "race") {
	// here loops through race categories 
	di "RACE"
	forvalues r = 0/1 { 
		preserve
		
		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt)

		// Construct outcome: aggregate count of alternate procedure at surgeon-year level
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
					inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
					
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		replace num_procs = 0 if race != `r' | !inrange(predicted_risk,`thetabar_l', `thetabar_u') // only look at share for low-income, crowd-out region patients.

		gen allprocs = 1
		collapse (sum) num_procs allprocs (mean) t_adopt, by(at_npi year) fast
		gen outcome = num_procs / allprocs * 100
		gen todrop = (allprocs < 10) // drop those with fewest procs
		bysort at_npi year: ereplace todrop = max(todrop)
		drop if todrop == 1

		do "$mydir/3_SourceCode/5_CrowdOut_Decomposition/4a_EventStudyFrag.do"

		// Save graphs
		graph save "$output/Inequities_Race_Group`r'_Intervention`surgeryout'.gph", replace
		graph export "$output/Inequities_Race_Group`r'_Intervention`surgeryout'.gph", as(pdf) replace
		restore
	}
}
********************************************************************************


***** 3. Estimate effect of TAVR adoption on likelihood of being crowded out. 
local het = "income" // "income" or "race"
local surgeryout = "all" // "all" for TAVR/SAVR, "pci" for only PCI (generally will only use all here?)
local thetabar_l = .05 // range of patient risk for crowd-out 
local thetabar_u = .15
if ("`het'" == "income") { 
	// here loops through 5 quintiles of income 
	forvalues q = 1/5 { 
		preserve
		keep if inrange(predicted_risk, `thetabar_l', `thetabar_u') // only look at patients in crowd-out region

		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt) // this is surgeon's first TAVR
		bysort bene_id: ereplace t_adopt = min(t_adopt) // at patient level, measure adoption as first time they see MD who has adopted
		
		// Construct outcome: aggregate count of alternate procedure at surgeon-year level
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
					inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
					
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		replace num_procs = 0 if incq != `q' // only look at share for group of interest

		collapse (max) num_procs (mean) t_adopt, by(bene_id year) fast
		gen outcome = (num_procs == 0)*100 // outcome: not receiving intervention

		do "$mydir/3_SourceCode/5_CrowdOut_Decomposition/4b_EventStudyFrag_Pats.do"

		// Save graphs
		graph save "$output/Inequities_ShareCrowdout_Income_Quintile`q'_Intervention`surgeryout'.gph", replace
		graph export "$output/Inequities_ShareCrowdout_Income_Quintile`q'_Intervention`surgeryout'", as(pdf) replace
		restore
	}
}
else if ("`het'" == "race") {
	// here loops through race categories 
	di "RACE"
	forvalues r = 0/1 { 
		preserve
		keep if inrange(predicted_risk, `thetabar_l', `thetabar_u') // only look at patients in crowd-out region
		
		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt) // this is surgeon's first TAVR
		bysort bene_id: ereplace t_adopt = min(t_adopt) // at patient level, measure adoption as first time they see MD who has adopted

		// Construct outcome: aggregate count of alternate procedure at surgeon-year level
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
					inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
					
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		replace num_procs = 0 if race != `r' // only look at share for group of interest

		collapse (max) num_procs (mean) t_adopt, by(bene_id year) fast
		gen outcome = (num_procs == 0)*100 // outcome: not receiving intervention

		do "$mydir/3_SourceCode/5_CrowdOut_Decomposition/4b_EventStudyFrag_Pats.do"

		// Save graphs
		graph save "$output/Inequities_ShareCrowdout_Race_Group`r'_Intervention`surgeryout'.gph", replace
		graph export "$output/Inequities_ShareCrowdout_Race_Group`r'_Intervention`surgeryout'", as(pdf) replace
		restore
	}
}
********************************************************************************


***** 4. Heterogeneity across income distribution
local myout = "volume" // Volume of all services, or likelihood of being in crowd-out region ("coregion")
local nq = 5 // number of quantiles to use for bins
local surgeryout = "all"
local thetabar_l = .05 // range of patient risk for crowd-out 
local thetabar_u = .20

*** Create blank data set of deciles in order to save DD coefficients
clear
set obs `nq'
gen deciles = _n
gen dd_coef = .
gen dd_se = .  
gen dd_lb = . 
gen dd_ub = . 
sort deciles
save "$datadir/Income_DDDecomposition.dta", replace

use "$datadir/IVCEventStudy_Base.dta" if year < 2016, clear
// Merge in income information
gen ssacd = state_cd + cnty_cd
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
rename fipsc fips_string
drop if missing(fips_string)
merge m:1 fips_string year using "$mydir/2_Data/Income/fips_income.dta", keep(1 3) 
	// note that almost 1/4 of counties are missing here, need to check
drop if _merge == 1  // for now
drop _merge
xtile deciles = medinc_65plus, nq(`nq')

if ("`myout'" == "volume") { 
	forvalues d = 1/`nq' { 
		preserve
		// keep if deciles == `d' // only look at patients in income decile of interest
		
		// Construct outcome: aggregate count of procedure at surgeon-year level
		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt)
		 
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		gen allprocs = 1 if deciles == `d' | inrange(predicted_risk,`thetabar_l', `thetabar_u')
		replace num_procs = 0 if deciles != `d' | !inrange(predicted_risk,`thetabar_l',`thetabar_u')
		collapse (sum) num_procs allprocs (mean) deciles predicted_risk t_adopt, by(at_npi year) fast
		gen outcome = ((num_procs / allprocs * 100))
		// replace outcome = 0 if deciles != `d' | !inrange(predicted_risk,`thetabar_l', `thetabar_u')

		// Generate relative time variables
		qui gen treated = (!missing(t_adopt))
		qui gen period_yr = year - t_adopt if treated == 1
		
		// Store mean before treatment 
		sum outcome if period_yr < 0 | missing(period_yr), d
		
		// Save DD coefficient in data set 
		gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
		reghdfe outcome post, absorb(at_npi year)
		local dd_coef = round(e(b)[1,1],.001)
		local dd_se = round(sqrt(e(V)[1,1]),.001)
		
		// Update DDDecomposition.dta
		use "$datadir/Income_DDDecomposition.dta", clear
		sort deciles
		replace dd_coef = `dd_coef' if deciles == `d'
		replace dd_se = `dd_se' if deciles == `d'
		save "$datadir/Income_DDDecomposition.dta", replace
		
		restore
	}

	// Generate figure across bins
	use "$datadir/Income_DDDecomposition.dta", clear
	replace dd_lb = dd_coef-1.96*dd_se
	replace dd_ub = dd_coef+1.96*dd_se
	twoway (scatter dd_coef deciles, color(maroon)) (rcap dd_lb dd_ub deciles, lcolor(ebblue%80)), ///
		graphregion(color(white)) legend(off) ///
		yline(0, lpattern(dash) lcolor(red)) ///
		xsc(r(1(1)`nq')) xlab(1(1)`nq') xtitle("Deciles of Patient Income") ///
		ylab(, angle(horizontal))
		
	// Save graphs
	//graph save "$output/Inequities_AllVolumes_IncomeNP_Intervention`surgeryout'.gph", replace
	//graph export "$output/Inequities_AllVolumes_IncomeNP_Intervention`surgeryout'.pdf", as(pdf) replace
}
else if ("`myout'" == "coregion") { 
	forvalues d = 1/`nq' { 
		preserve
		// keep if deciles == `d' // only look at patients in income decile of interest
		
		// Construct outcome: aggregate count of procedure at surgeon-year level
		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt)
		 
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		gen outcome = (num_procs == 0 & deciles == `d' & inrange(predicted_risk,`thetabar_l',`thetabar_u'))
		collapse (sum) outcome (mean) t_adopt, by(at_npi year) fast
		replace outcome = (outcome) * 100

		// Generate relative time variables
		qui gen treated = (!missing(t_adopt))
		qui gen period_yr = year - t_adopt if treated == 1
		
		// Save DD coefficient in data set 
		gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
		reghdfe outcome post, absorb(at_npi year)
		local dd_coef = round(e(b)[1,1],.001)
		local dd_se = round(sqrt(e(V)[1,1]),.001)
		
		// Update DDDecomposition.dta
		use "$datadir/Income_DDDecomposition.dta", clear
		sort deciles
		replace dd_coef = `dd_coef' if deciles == `d'
		replace dd_se = `dd_se' if deciles == `d'
		save "$datadir/Income_DDDecomposition.dta", replace
		
		restore
	}

	// Generate figure across bins
	use "$datadir/Income_DDDecomposition.dta", clear
	replace dd_lb = dd_coef-1.96*dd_se
	replace dd_ub = dd_coef+1.96*dd_se
	twoway (scatter dd_coef deciles, color(maroon)) (rcap dd_lb dd_ub deciles, lcolor(ebblue%80)), ///
		graphregion(color(white)) legend(off) ///
		yline(0, lpattern(dash) lcolor(red)) ///
		xsc(r(1(1)`nq')) xlab(1(1)`nq') xtitle("Deciles of Patient Income") ///
		ylab(, angle(horizontal))
		
	// Save graphs
	graph save "$output/Inequities_ShareCrowdout_IncomeNP_Intervention`surgeryout'.gph", replace
	graph export "$output/Inequities_ShareCrowdout_IncomeNP_Intervention`surgeryout'.pdf", as(pdf) replace
}
********************************************************************************


***** 5. Heterogeneity across race
local myout = "volume" // Volume of all services, or likelihood of being in crowd-out region ("coregion")
local surgeryout = "all"
local thetabar_l = .05 // range of patient risk for crowd-out 
local thetabar_u = .20

*** Create blank data set of deciles in order to save DD coefficients
clear
set obs 2
gen race = _n-1
gen dd_coef = .
gen dd_se = .  
gen dd_lb = . 
gen dd_ub = . 
sort race
save "$datadir/Race_DDDecomposition.dta", replace

use "$datadir/IVCEventStudy_Base.dta" if year < 2016, clear
// Merge in income information
gen ssacd = state_cd + cnty_cd
merge m:1 ssacd using "$geodata/SSA_FIPS", keep(1 3) keepusing(fipsc) nogenerate
rename fipsc fips_string
drop if missing(fips_string)
merge m:1 fips_string year using "$mydir/2_Data/Income/fips_income.dta", keep(1 3) 
	// note that almost 1/4 of counties are missing here, need to check
drop if _merge == 1  // for now
drop _merge
destring race_cd, replace
gen white = (race_cd == 1)

if ("`myout'" == "volume") { 
	forvalues r = 0/1 { 
		preserve
		
		// Construct outcome: aggregate count of procedure at surgeon-year level
		*** Identify treatment (first adoption of tavr) 
		gen t_adopt = year if tavr == 1
		bysort at_npi: ereplace t_adopt = min(t_adopt)
		 
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
		if ("`surgeryout'" == "all") { 
			replace num_procs = 1 if tavr == 1 | savr == 1
		}
		
		gen allprocs = 1 
		replace num_procs = 0 if white != `r' | !inrange(predicted_risk,`thetabar_l',`thetabar_u')
		collapse (sum) num_procs allprocs (mean) t_adopt, by(at_npi year) fast
		gen outcome = (num_procs / allprocs * 100)

		// Generate relative time variables
		qui gen treated = (!missing(t_adopt))
		qui gen period_yr = year - t_adopt if treated == 1
		
		// Save DD coefficient in data set 
		gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
		reghdfe outcome post, absorb(at_npi year)
		local dd_coef = round(e(b)[1,1],.001)
		local dd_se = round(sqrt(e(V)[1,1]),.001)
		
		// Update DDDecomposition.dta
		use "$datadir/Race_DDDecomposition.dta", clear
		sort race
		replace dd_coef = `dd_coef' if race == `r'
		replace dd_se = `dd_se' if race == `r'
		save "$datadir/Race_DDDecomposition.dta", replace
		
		restore
	}

	// Generate figure across bins
	use "$datadir/Race_DDDecomposition.dta", clear
	replace dd_lb = dd_coef-1.96*dd_se
	replace dd_ub = dd_coef+1.96*dd_se
	twoway (scatter dd_coef race, color(maroon)) (rcap dd_lb dd_ub race, lcolor(ebblue%80)), ///
		graphregion(color(white)) legend(off) ///
		yline(0, lpattern(dash) lcolor(red)) ///
		xsc(r(0(1)1)) xlab(0 "Non-White" 1 "White") xtitle("Patient Race") ///
		ylab(, angle(horizontal))
		
	// Save graphs
	graph save "$output/Inequities_AllVolumes_RaceNP_Intervention`surgeryout'.gph", replace
	graph export "$output/Inequities_AllVolumes_RaceNP_Intervention`surgeryout'", as(pdf) replace
}
else if ("`myout'" == "coregion") { 
	di "HELP"
}
********************************************************************************
