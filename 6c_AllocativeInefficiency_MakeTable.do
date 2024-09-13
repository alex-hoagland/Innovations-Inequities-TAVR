/*******************************************************************************
* Title: Make a regression table for the allocative inefficiencies regressions
* Created by: Alex Hoagland
* Created on: 8/2024
* Last modified on: 
* Last modified by: 
* Purpose: 
* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Create table 
texdoc init "$output/AllocativeInefficiencyTable.tex", replace force
tex \begin{table}[H]
tex \centering
tex \begin{threeparttable}
tex \begin{tabular}{l|c|cccc}
tex \toprule
tex & Full Sample & \multicolumn{4}{c}{Quartile, Risk-Adjusted Treatment Thresholds} \\
tex & & Q1 & Q2 & Q3 & Q4 \\
tex \midrule
tex \(\hat{\theta}_{CZ}\) & -- & [-0.46, -0.08] & [-0.08, -0.01] & [-0.01, 0.08] & [0.08, 0.51] \\ 
tex \midrule 
tex Treatment Effect, & -3.87 & ${b_q1} & ${b_q2} & ${b_q3} & ${b_q4} \\
tex \text{   } TAVR Adoption & (1.673) & (${se_q1}) & (${se_q2}) & (${se_q3}) & (${se_q4}) \\
tex \(p\)-value & [0.021] & [${p_q1}] & [${p_q2}] & [${p_q3}] & [${p_q4}] \\
tex \midrule 
tex \(N\) & 2,922 & ${N_q1} & ${N_q2} & ${N_q3} & ${N_q4} \\ 
tex \bottomrule
tex \end{tabular}
tex \begin{tablenotes}
tex    \small
tex    \item \textit{Notes}: Table reports pooled effects from LP-DID regressions estimating the effect of TAVR's adoption in a local market (measured as a commuting zone) on total intervention volume per quarter. Compare with Figure \ref{fig:tavr-response-cz}. Results are stratified based on each market's risk-adjusted probability to treat a patient with valve replacement or supports, conditional on patient characteristics (\(\hat{\theta}_{CZ}\) in Equation \ref{eq:propensity}). Treatment thresholds are estimated using pre-adoption data only. 
tex    \end{tablenotes}
tex    \caption{\label{tab:allocative-inefficiencies} Effects of TAVR Adoption on Local Intervention Volume: By Pre-TAVR Propensity to Treat} 
tex \end{threeparttable}
tex \end{table}
texdoc close 
********************************************************************************


