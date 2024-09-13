/*******************************************************************************
* Title: Make a summary stat table for patient-level inequity (LPDID) regressions
* Created by: Alex Hoagland
* Created on: 3/1/2024
* Last modified on: 3/25/2024
* Last modified by: 
* Purpose: 
* Notes: - uses texdoc based on previous regressions in "4e_Inequities_Patient20p_lpdid_Table.do"

* Key edits: 
*******************************************************************************/


***** 1. Make the table from globals 
texdoc init "$output/PatientInequities_LPDIDTable_WITHOUTPATIENT.tex", replace force
tex \begin{table}[H]
tex \centering
tex \begin{threeparttable}
tex \begin{tabular}{l|cccc}
tex \toprule
tex Group & Estimate & \% Change & 95\% Confidence Interval & \$p\$-value, difference \\
tex \midrule
tex Overall & $pooledfx1_0 & $percchange1_0 & [$pooledfx1_cil_0, $pooledfx1_cih_0] & --- \\ 
tex \midrule
tex \textbf{Panel A:} Patient Geography \\ 
tex ADI: Lowest Decile & $pooledfx1_4 & $percchange1_4 & [$pooledfx1_cil_4, $pooledfx1_cih_4] & --- \\ 
tex ADI: Highest Decile & $pooledfx2_4 & $percchange2_4 & [$pooledfx2_cil_4, $pooledfx2_cih_4] & $group4_p \\ 
tex \midrule 
tex \textbf{Panel B:} Patient Eligibility \\
tex Not Dual Eligible & $pooledfx1_2 & $percchange1_2 & [$pooledfx1_cil_2, $pooledfx1_cih_2] & --- \\
tex Dual Eligible & $pooledfx2_2 & $percchange2_2 & [$pooledfx2_cil_2, $pooledfx2_cih_2] & $group2_p \\  
tex \midrule 
tex \textbf{Panel C:} Patient Race \\
tex White & $pooledfx1_3 & $percchange1_3 & [$pooledfx1_cil_3, $pooledfx1_cih_3] & --- \\ 
tex Black & $pooledfx2_3 & $percchange2_3 & [$pooledfx2_cil_3, $pooledfx2_cih_3] & $group3_p \\ 
tex Hispanic & $pooledfx3_3 & $percchange3_3 & [$pooledfx3_cil_3, $pooledfx3_cih_3] & $group3_p_3 \\ 
tex Other Non-White & $pooledfx4_3 & $percchange4_3 & [$pooledfx4_cil_3, $pooledfx4_cih_3] & $group3_p_4 \\ 
tex Any Non-White & $pooledfx5_3 & $percchange5_3 & [$pooledfx5_cil_3, $pooledfx5_cih_3] & $group3_p_5 \\ 
tex \midrule 
tex \textbf{Panel D:} Patient Sex \\
tex Male & $pooledfx1_1 & $percchange1_1 & [$pooledfx1_cil_1, $pooledfx1_cih_1] & --- \\ 
tex Female & $pooledfx2_1 & $percchange2_1 & [$pooledfx2_cil_1, $pooledfx2_cih_1] & $group1_p \\ 
tex \bottomrule
tex \end{tabular}
tex \begin{tablenotes}
tex    \small
tex    \item \textit{Notes}: Table presents estimates of Equation \ref{eq:es}, stratified by patient groups. The outcome variable is the count of interventions performed within the patient group at the CZ level; markets with $\leq 5$ procedures quarterly are dropped. Reported coefficients are pooled average post-treatment effects over 16 quarters post-adoption. Patients and demographic information are identified based on the 20\% carrier file. Standard errors are clustered at the CZ level. Percentage changes are relative to the mean CZ-quarter intervention volume for the indicated group; results are robust to considering the median instead.
tex    \end{tablenotes}
tex    \caption{\label{tab:inequities-patients} Within-Market Inequities: Pooled LP-DID Estimates}
tex \end{threeparttable}
tex \end{table}
texdoc close 

// rm "$datadir/regdata.dta"
********************************************************************************



***** Here's an old version that reports p-values from pooled effects rather than comparisons
// texdoc init "$output/PatientInequities_LPDIDTable_WITHOUTPATIENT.tex", replace force
// tex \begin{table}[H]
// tex \centering
// tex \begin{threeparttable}
// tex \begin{tabular}{l|cccc}
// tex \toprule
// tex Group & Estimate & \% Change & 95\% Confidence Interval & \$p\$-value\\
// tex \midrule
// tex Overall & $pooledfx_0 & $percchange_0 & [$pooledfx_cil_0, $pooledfx_cih_0] & $pooledfx_p_0 \\ 
// tex \midrule
// tex \textbf{Panel A:} Patient Geography \\ 
// tex ADI: Lowest Quintile & $pooledfx_10 & $percchange_10 & [$pooledfx_cil_10, $pooledfx_cih_10] & $pooledfx_p_10 \\ 
// tex ADI: Highest Quintile & $pooledfx_11 & $percchange_11 & [$pooledfx_cil_11, $pooledfx_cih_11] & $pooledfx_p_11 \\ 
// tex \midrule 
// tex \textbf{Panel B:} Patient Eligibility \\
// tex Not Dual Eligible & $pooledfx_4 & $percchange_4 & [$pooledfx_cil_4, $pooledfx_cih_4] & $pooledfx_p_4 \\
// tex Dual Eligible & $pooledfx_3 & $percchange_3 & [$pooledfx_cil_3, $pooledfx_cih_3] & $pooledfx_p_3 \\  
// tex \midrule 
// tex \textbf{Panel C:} Patient Race \\
// tex White & $pooledfx_5 & $percchange_5 & [$pooledfx_cil_5, $pooledfx_cih_5] & $pooledfx_p_5 \\ 
// tex Black & $pooledfx_6 & $percchange_6 & [$pooledfx_cil_6, $pooledfx_cih_6] & $pooledfx_p_6 \\ 
// tex Hispanic & $pooledfx_7 & $percchange_7 & [$pooledfx_cil_7, $pooledfx_cih_7] & $pooledfx_p_7 \\ 
// tex Other Non-White & $pooledfx_8 & $percchange_8 & [$pooledfx_cil_8, $pooledfx_cih_8] & $pooledfx_p_8 \\ 
// tex Any Non-White & $pooledfx_9 & $percchange_9 & [$pooledfx_cil_9, $pooledfx_cih_9] & $pooledfx_p_9 \\ 
// tex \midrule 
// tex \textbf{Panel D:} Patient Sex \\
// tex Male & $pooledfx_1 & $percchange_1 & [$pooledfx_cil_1, $pooledfx_cih_1] & $pooledfx_p_1 \\ 
// tex Female & $pooledfx_2 & $percchange_2 & [$pooledfx_cil_2, $pooledfx_cih_2] & $pooledfx_p_2 \\ 
// tex \bottomrule
// tex \end{tabular}
// tex \begin{tablenotes}
// tex    \small
// tex    \item \textit{Notes}: Table presents estimates Equation \ref{eq:es}, stratified by patient groups. The outcome variable is the count of interventions performed within the patient group at the CZ level; markets with \$\leq 5\$ procedures quarterly are dropped. Reported coefficients are ``pooled" average post-treatment effects over 16 quarters post-adoption. Patients and demographic information are identified based on the 20\% carrier file. Standard errors are clustered at the CZ level. Percentage changes are relative to the mean CZ-quarter intervention volume for the indicated group; results are robust to considering the median instead.
// tex    \end{tablenotes}
// tex    \caption{\label{tab:inequities-patients} Within-Market Inequities: Pooled LP-DID Estimates}
// tex \end{threeparttable}
// tex \end{table}
// texdoc close 
********************************************************************************


