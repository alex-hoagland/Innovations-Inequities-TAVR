/*******************************************************************************
* Title: Make a summary stat table for procedure types
* Created by: Alex Hoagland
* Created on: 2/28/2022
* Last modified on: 2/2024
* Last modified by: 
* Purpose: 
* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Identify providers of valve replacement surgeries
use "$datadir/IVCEventStudy_Base.dta", clear

// keep only year of adoption 
cap drop t_adopt
gen t_adopt = year if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)
keep if year == t_adopt 

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

gen allreplace = 0 // all PCIs
replace allreplace = 1 if savr == 1 | tavr == 1 // all valve replacements
gen allpci = (allreplace == 0)
********************************************************************************


***** Summarize
// variables we want are total/OOP (?) cost, LOS, mortality, readmission, time of surgery, surgical team size 
// do this for all valve replacements, SAVR, TAVR, PTCA, catherization, and all PCIs
// panel b: patient age, sex, black/hisp/other, dual eligible

// update definitions of risk, mortality, and readmission
gen days_death = death_dt - surg_dt + 1 
replace days_death = . if missing(death_dt) | death_dt < surg_dt
gen mortality = (days_death <= 30 & !missing(days_death))

gen readmit = (days_readmit <= 30 & !missing(days_readmit))
replace predrisk_30 = predrisk_30 * 100 

// make SE variables for easy collapse
foreach v of varlist pmt_amt riskvar_* mortality readmit predrisk_30 { 
	gen se_`v' = `v' 
}

foreach v of varlist riskvar_fem riskvar_black riskvar_hisp riskvar_other riskvar_dual* readmit mortality { 
	rename se_`v' seb_`v' 
}

foreach v of varlist allreplace tavr savr allpci ptcaonly cath cabg { 
	preserve
	di "***** CATEGORY `v' *****"
	keep if `v' == 1
	global N_`v' : di %9.0fc _N
	gcollapse (mean) pmt_amt riskvar_* mortality readmit predrisk_30 (sem) se_* (seb) seb_*, fast
	// change to %
	foreach x of varlist mortality readmit { 
		replace `x' = `x' * 100
		replace seb_`x' = seb_`x' * 100
	}
	// list in 1
	
	// Panel A: Costs, etc. 
	global b_cost_`v': di %6.0fc pmt_amt[1]
	global b_readmission_`v': di %4.2fc readmit[1]
	global b_mortality_`v': di %4.2fc mortality[1]
	global b_risk_`v': di %4.2fc predrisk_30[1]
	
	global se_cost_`v': di %4.0fc se_pmt_amt[1]
	global se_readmission_`v': di %4.3fc seb_readmit[1]
	global se_mortality_`v': di %4.3fc seb_mortality[1]
	global se_risk_`v': di %4.3fc se_predrisk_30[1]
	
	// Panel B: demographics
	global b_age_`v': di %6.1fc riskvar_age[1]
	di $b_age_allpci
	global b_fem_`v': di %6.2fc riskvar_fem[1]
	global b_bl_`v': di %6.2fc riskvar_bl[1]
	global b_hi_`v': di %6.2fc riskvar_hi[1]
	global b_ot_`v': di %6.2fc riskvar_other[1]
	global b_dual_`v': di %6.2fc riskvar_dual_any[1]
	
	global se_age_`v': di %4.2fc se_riskvar_age[1]
	global se_fem_`v': di %4.3fc seb_riskvar_fem[1]
	global se_bl_`v': di %4.3fc seb_riskvar_bl[1]
	global se_hi_`v': di %4.3fc seb_riskvar_hi[1]
	global se_ot_`v': di %4.3fc seb_riskvar_other[1]
	global se_dual_`v': di %4.3fc seb_riskvar_dual_any[1]
	
	restore
	
}

texdoc init "$output/ProcedureSummaryTable.tex", replace force
tex \begin{table}[H]
tex \centering
tex \begin{threeparttable}
tex \begin{tabular}{l|ccc|cccc}
tex \toprule
tex & \multicolumn{3}{c}{Valve Replacements} & \multicolumn{4}{c}{Valve Supports}\\\cmidrule{2-4}\cmidrule{5-8} 
tex & All & SAVR & TAVR & All & PTCA & Cath. & CABG \\
tex \midrule
tex \multicolumn{3}{l}{\textbf{Panel A:} Procedure Costs and Risks} \\ 
tex Billed Cost & \\$$b_cost_allreplace & \\$$b_cost_savr & \\$$b_cost_tavr & \\$$b_cost_allpci & \\$$b_cost_ptcaonly & \\$$b_cost_cath & \\$$b_cost_cabg \\ 
tex & (\\$${se_cost_allreplace}) & (\\$${se_cost_savr}) & (\\$${se_cost_tavr}) & (\\$${se_cost_allpci})  & (\\$${se_cost_ptcaonly}) & (\\$${se_cost_cath}) & (\\$${se_cost_cabg})  \\
tex Patient Risk & $b_risk_allreplace & $b_risk_savr & $b_risk_tavr & $b_risk_allpci & $b_risk_ptcaonly & $b_risk_cath & $b_risk_cabg \\
tex & (${se_risk_allreplace}) & (${se_risk_savr}) & (${se_risk_tavr}) & (${se_risk_allpci})  & (${se_risk_ptcaonly}) & (${se_risk_cath}) & (${se_risk_cabg})  \\
tex Readmission & $b_readmission_allreplace & $b_readmission_savr & $b_readmission_tavr & $b_readmission_allpci & $b_readmission_ptcaonly & $b_readmission_cath & $b_readmission_cabg \\
tex & (${se_readmission_allreplace}) & (${se_readmission_savr}) & (${se_readmission_tavr}) & (${se_readmission_allpci})  & (${se_readmission_ptcaonly}) & (${se_readmission_cath}) & (${se_readmission_cabg})  \\
tex Mortality & $b_mortality_allreplace & $b_mortality_savr & $b_mortality_tavr & $b_mortality_allpci & $b_mortality_ptcaonly & $b_mortality_cath & $b_mortality_cabg \\ 
tex & (${se_mortality_allreplace}) & (${se_mortality_savr}) & (${se_mortality_tavr}) & (${se_mortality_allpci})  & (${se_mortality_ptcaonly}) & (${se_mortality_cath}) & (${se_mortality_cabg})  \\
tex \midrule 
tex \multicolumn{3}{l}{\textbf{Panel B:} Patient Demographics} \\ 
tex Age & $b_age_allreplace & $b_age_savr & $b_age_tavr & $b_age_allpci & $b_age_ptcaonly & $b_age_cath & $b_age_cabg \\ 
tex & (${se_age_allreplace}) & (${se_age_savr}) & (${se_age_tavr}) & (${se_age_allpci})  & (${se_age_ptcaonly}) & (${se_age_cath}) & (${se_age_cabg})  \\
tex Female & $b_fem_allreplace & $b_fem_savr & $b_fem_tavr & $b_fem_allpci & $b_fem_ptcaonly & $b_fem_cath & $b_fem_cabg \\
tex & (${se_fem_allreplace}) & (${se_fem_savr}) & (${se_fem_tavr}) & (${se_fem_allpci})  & (${se_fem_ptcaonly}) & (${se_fem_cath}) & (${se_fem_cabg}) \\
tex Black & $b_bl_allreplace & $b_bl_savr & $b_bl_tavr & $b_bl_allpci & $b_bl_ptcaonly & $b_bl_cath  & $b_bl_cabg \\ 
tex & (${se_bl_allreplace}) & (${se_bl_savr}) & (${se_bl_tavr}) & (${se_bl_allpci})  & (${se_bl_ptcaonly}) & (${se_bl_cath}) & (${se_bl_cabg}) \\
tex Hispanic & $b_hi_allreplace & $b_hi_savr & $b_hi_tavr & $b_hi_allpci & $b_hi_ptcaonly & $b_hi_cath & $b_hi_cabg \\
tex & (${se_hi_allreplace}) & (${se_hi_savr}) & (${se_hi_tavr}) & (${se_hi_allpci})  & (${se_hi_ptcaonly}) & (${se_hi_cath})  & (${se_hi_cabg}) \\
tex Other Minority Race & $b_ot_allreplace & $b_ot_savr & $b_ot_tavr & $b_ot_allpci & $b_ot_ptcaonly & $b_ot_cath & $b_ot_cabg \\
tex & (${se_ot_allreplace}) & (${se_ot_savr}) & (${se_ot_tavr}) & (${se_ot_allpci})  & (${se_ot_ptcaonly}) & (${se_ot_cath})  & (${se_ot_cabg})  \\
tex Dual Eligible & $b_dual_allreplace & $b_dual_savr & $b_dual_tavr & $b_dual_allpci & $b_dual_ptcaonly & $b_dual_cath  & $b_dual_cabg \\
tex & (${se_dual_allreplace}) & (${se_dual_savr}) & (${se_dual_tavr}) & (${se_dual_allpci})  & (${se_dual_ptcaonly}) & (${se_dual_cath}) & (${se_dual_cabg})  \\
tex \midrule
tex Total Volume & $N_allreplace & $N_savr & $N_tavr & $N_allpci & $N_ptcaonly & $N_cath & $N_cabg \\
tex \bottomrule
tex \end{tabular}
tex \begin{tablenotes}
tex    \small
tex    \item \textit{Notes}: Table shows summary statistics from relevant cardiology procedures from 2010--2017, with standard errors in parentheses. Means are shown for the year of TAVR adoption (defined at the CZ level) to illustrate differnces at the time of innovation. Cath. refers to cardiac catheterization. Patient risk is predicted using the STS-PROM model with 30-day mortality as the outcome; patient readmission and mortality rates are also reported at the 30-day level. 
tex    \end{tablenotes}
tex    \caption{\label{tab:sumstats-procs} Summary Statistics: Procedures}
tex \end{threeparttable}
tex \end{table}
texdoc close 
