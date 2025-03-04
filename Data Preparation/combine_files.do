/*=============================================================================* 
* Sex and Ethnic Segregation across Wage Ranks in Large Dutch Organizations,
* 2011-2023
*==============================================================================*
 	Project: Beyond Boardroom 
	Author: Christoph Janietz (c.janietz@rug.nl)
	Last update: 25-02-2025
* ---------------------------------------------------------------------------- *

	INDEX: 
		0.  SETTINGS 
		1.  COMBINING FINAL FILES
		
* Short description of output:
*
* - Wage rank composition data by sex and ethnicity
*
* NIDIO files used:
* - spolis_month_2006_2023
* - gba_rin_2023
* - abr_ogbe_register_2006_2023
* - bdk_be_2007_2023

* --------------------------------------------------------------------------- */
* 0. SETTINGS 
* ---------------------------------------------------------------------------- * 

*** Settings - run config file
	global sdir 		"H:/Syntax"			// Syntax Working Directory
	do 					"${sdir}/config"
	
	global wdir			"H:/Projects/CJ/segregation"
	global sdir			"H:/Projects/CJ/segregation/sex/analysis"
	global edir			"H:/Projects/CJ/segregation/ethnic/analysis"
	
* --------------------------------------------------------------------------- */
* 1. COMBINING FINAL FILES
* ---------------------------------------------------------------------------- *

	// Harmonize wage rank variable
	foreach x in d q {
		use "${sdir}/`x'_shares/within`x'_sex", replace
		rename within`x' rank
		save "${wdir}/swithin`x'", replace
	}
	*
	
	foreach x in d q {
		use "${edir}/`x'_shares/within`x'_ethnicity", replace
		rename within`x' rank
		save "${wdir}/ewithin`x'", replace
	}
	*
	
	// Append files
	* Ethnic segregation
	use "${wdir}/ewithind", replace
	append using "${wdir}/ewithinq"
	save "${wdir}/ethnicseg", replace
	export excel using "${wdir}/ethnicseg", firstrow(variables) replace
	
	erase "${wdir}/ewithind.dta"
	erase "${wdir}/ewithinq.dta"
	
	
	* Ethnic segregation
	use "${wdir}/swithind", replace
	append using "${wdir}/swithinq"
	save "${wdir}/sexseg", replace
	export excel using "${wdir}/sexseg", firstrow(variables) replace
	
	erase "${wdir}/swithind.dta"
	erase "${wdir}/swithinq.dta"
	
