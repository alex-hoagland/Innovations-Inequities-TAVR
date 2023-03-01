/*******************************************************************************
* Title: Make a summary stat table for TAVR patients
* Created by: Alex Hoagland
* Created on: 2/28/2022
* Last modified on: 2/9/2023
* Last modified by: 
* Purpose: 
* Notes: - updated to be for all patients, including those with/without TAVR/SAVR/PCI

* Key edits: 
*******************************************************************************/


***** 1. Identify patient groups (TAVR, SAVR, PCI, all) 
use "$datadir/all_SurgicalCandidates.dta", clear
gcollapse (max) tavr savr ptca riskvar_fem riskvar_black riskvar_hisp riskvar_other /// 
	riskvar_cc_* (mean) riskvar_age riskvar_income riskvar_numcc riskvar_dual* riskvar_adi*  ///
	riskvar_prev* riskvar_ed* riskvar_st* riskvar_days* predrisk*, by(bene_id) fast // collapse to patient 
gen all = 1 

// make SE variables for easy collapse
foreach v of varlist riskvar_* predrisk* { 
	gen se_`v' = `v' 
}

foreach v of varlist riskvar_fem riskvar_black riskvar_hisp riskvar_other riskvar_cc* riskvar_dual* riskvar_prev* { 
	rename se_`v' seb_`v' 
}

foreach v of varlist tavr savr ptca all { 
	preserve
	di "***** CATEGORY `v' *****"
	keep if `v' == 1
	global N_`v' : di %12.0fc _N
	gcollapse (mean) riskvar_* predrisk* (sem) se_* (seb) seb_*, fast
	
	// Panel A: demographics
	global b_age_`v': di %6.1fc riskvar_age[1]
	global b_fem_`v': di %6.2fc riskvar_fem[1]
	global b_bl_`v': di %6.2fc riskvar_bl[1]
	global b_hi_`v': di %6.2fc riskvar_hi[1]
	global b_ot_`v': di %6.2fc riskvar_other[1]
	global b_inc_`v': di %6.0fc riskvar_inc[1]
	global b_adi_`v': di %6.1fc riskvar_adi_9[1]
	global b_dual_`v': di %6.2fc riskvar_dual_any[1]
	global b_30_`v': di %6.2fc predrisk_30[1]
	global b_90_`v': di %6.2fc predrisk_90[1]
	global b_60_`v': di %6.2fc predrisk_60[1]
	
	global se_age_`v': di %6.3fc se_riskvar_age[1]
	global se_fem_`v': di %6.3fc seb_riskvar_fem[1]
	global se_bl_`v': di %6.3fc seb_riskvar_bl[1]
	global se_hi_`v': di %6.3fc seb_riskvar_hi[1]
	global se_ot_`v': di %6.3fc seb_riskvar_other[1]
	global se_inc_`v': di %6.3fc se_riskvar_inc[1]
	global se_adi_`v': di %6.3fc se_riskvar_adi_9[1]
	global se_dual_`v': di %6.3fc seb_riskvar_dual_any[1]
	global se_30_`v': di %6.3fc se_predrisk_30[1]
	global se_90_`v': di %6.3fc se_predrisk_90[1]
	global se_60_`v': di %6.3fc se_predrisk_60[1]
	
	// Panel B: Chronic Conditions
	global b_ncc_`v': di %6.1fc riskvar_numcc[1]
	global b_chf_`v': di %6.2fc riskvar_cc_chf[1]
	global b_copd_`v': di %6.2fc riskvar_cc_copd[1]
	global b_hyp_`v': di %6.2fc riskvar_cc_hyp[1]
	global b_dia_`v': di %6.2fc riskvar_cc_diab[1]
	global b_ami_`v': di %6.2fc riskvar_cc_ami[1]
	global b_str_`v': di %6.2fc riskvar_cc_str[1]
	
	global se_ncc_`v': di %6.3fc se_riskvar_numcc[1]
	global se_chf_`v': di %6.3fc seb_riskvar_cc_chf[1]
	global se_copd_`v': di %6.3fc seb_riskvar_cc_copd[1]
	global se_hyp_`v': di %6.3fc seb_riskvar_cc_hyp[1]
	global se_dia_`v': di %6.3fc seb_riskvar_cc_diab[1]
	global se_ami_`v': di %6.3fc seb_riskvar_cc_ami[1]
	global se_str_`v': di %6.3fc seb_riskvar_cc_str[1]
	restore
	
}
********************************************************************************


***** 2. Create table 
texdoc init "$output/PatientSummaryTable.tex", replace force
tex \begin{table}[H]
tex \centering
tex \begin{threeparttable}
tex \begin{tabular}{l|cccc}
tex \toprule
tex & All & PCI & SAVR & TAVR \\
tex \midrule
tex \textbf{Panel A:} Demographics \\ 
tex Age & $b_age_all & $b_age_ptca & $b_age_savr & $b_age_tavr \\ 
tex & (${se_age_all}) & (${se_age_ptca}) & (${se_age_savr}) &  (${se_age_tavr}) \\
tex Female & $b_fem_all & $b_fem_ptca & $b_fem_savr & $b_fem_tavr \\
tex & (${se_fem_all}) & (${se_fem_ptca}) & (${se_fem_savr}) &  (${se_fem_tavr}) \\
tex Black & $b_bl_all & $b_bl_ptca & $b_bl_savr & $b_bl_tavr \\ 
tex & (${se_bl_all}) & (${se_bl_ptca}) & (${se_bl_savr}) &  (${se_bl_tavr}) \\
tex Hispanic & $b_hi_all & $b_hi_ptca & $b_hi_savr & $b_hi_tavr \\
tex & (${se_hi_all}) & (${se_hi_ptca}) & (${se_hi_savr}) &  (${se_hi_tavr}) \\
tex Other Minority Race & $b_ot_all & $b_ot_ptca & $b_ot_savr & $b_ot_tavr \\
tex & (${se_ot_all}) & (${se_ot_ptca}) & (${se_ot_savr}) &  (${se_ot_tavr}) \\
tex Log(income) & $b_inc_all & $b_inc_ptca & $b_inc_savr & $b_inc_tavr \\ 
tex & (${se_inc_all}) & (${se_inc_ptca}) & (${se_inc_savr}) &  (${se_inc_tavr}) \\
tex ADI & $b_adi_all & $b_adi_ptca & $b_adi_savr & $b_adi_tavr \\
tex & (${se_adi_all}) & (${se_adi_ptca}) & (${se_adi_savr}) &  (${se_adi_tavr}) \\
tex Dual Eligible & $b_dual_all & $b_dual_ptca & $b_dual_savr & $b_dual_tavr \\
tex & (${se_dual_all}) & (${se_dual_ptca}) & (${se_dual_savr}) &  (${se_dual_tavr}) \\
tex Predicted Risk: 30-day & $b_30_all & $b_30_ptca & $b_30_savr & $b_30_tavr \\
tex & (${se_30_all}) & (${se_30_ptca}) & (${se_30_savr}) &  (${se_30_tavr}) \\
tex Predicted Risk: 60-day & $b_60_all & $b_60_ptca & $b_60_savr & $b_60_tavr  \\
tex & (${se_60_all}) & (${se_60_ptca}) & (${se_60_savr}) &  (${se_60_tavr}) \\
tex Predicted Risk: 90-day & $b_90_all & $b_90_ptca & $b_90_savr & $b_90_tavr \\
tex & (${se_90_all}) & (${se_90_ptca}) & (${se_90_savr}) &  (${se_90_tavr}) \\
tex \midrule 
tex \textbf{Panel B:} Chronic Conditions \\ 
tex \# of Chronic Conditions & $b_ncc_all & $b_ncc_ptca & $b_ncc_savr & $b_ncc_tavr \\
tex & (${se_ncc_all}) & (${se_ncc_ptca}) & (${se_ncc_savr}) &  (${se_ncc_tavr}) \\
tex AMI & $b_ami_all & $b_ami_ptca & $b_ami_savr & $b_ami_tavr \\
tex & (${se_ami_all}) & (${se_ami_ptca}) & (${se_ami_savr}) &  (${se_ami_tavr}) \\
tex CHF & $b_chf_all & $b_chf_ptca & $b_chf_savr & $b_chf_tavr \\
tex & (${se_chf_all}) & (${se_chf_ptca}) & (${se_chf_savr}) &  (${se_chf_tavr}) \\
tex COPD &$b_copd_all & $b_copd_ptca & $b_copd_savr & $b_copd_tavr  \\
tex & (${se_copd_all}) & (${se_copd_ptca}) & (${se_copd_savr}) &  (${se_copd_tavr}) \\
tex Diabetes & $b_dia_all & $b_dia_ptca & $b_dia_savr & $b_dia_tavr \\
tex & (${se_dia_all}) & (${se_dia_ptca}) & (${se_dia_savr}) &  (${se_dia_tavr}) \\
tex Hypertension & $b_hyp_all & $b_hyp_ptca & $b_hyp_savr & $b_hyp_tavr \\
tex & (${se_hyp_all}) & (${se_hyp_ptca}) & (${se_hyp_savr}) &  (${se_hyp_tavr}) \\
tex Stroke & $b_str_all & $b_str_ptca & $b_str_savr & $b_str_tavr \\
tex & (${se_str_all}) & (${se_str_ptca}) & (${se_str_savr}) &  (${se_str_tavr}) \\
tex \bottomrule
tex \end{tabular}
tex \begin{tablenotes}
tex    \small
tex    \item \textit{Notes}: Table shows summary statistics from cardiology pateints from 2010--2017. 
tex    \end{tablenotes}
tex    \caption{\label{tab:sumstats-patients} Summary Statistics: Patients}
tex \end{threeparttable}
tex \end{table}
texdoc close 
********************************************************************************


