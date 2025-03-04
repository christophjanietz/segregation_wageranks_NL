/*=============================================================================* 
* Pay Decile Analysis - Ethnic Segregation across Wage Ranks
*==============================================================================*
 	Project: Beyond Boardroom 
	Author: Christoph Janietz (c.janietz@rug.nl)
	Last update: 22-02-2025
* ---------------------------------------------------------------------------- *

	INDEX: 
		0.  SETTINGS 
		1.  PREPARING INDIVIDUAL-LEVEL WAGE DATA
		2.  DECILE SHARES (NOT WEIGHTED)
		3.  DECILE SHARES (WEIGHTED BY FIRM SIZE)
		4.  COMBINE FILES
		
* Short description of output:
*
* - Create files holding information on within-organization pay decile shares
*   of Western and Non-western employees.
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
	
	global wdir			"H:/Projects/CJ/segregation/ethnic"
	global adir			"H:/Projects/CJ/segregation/ethnic/analysis/d_shares"

* --------------------------------------------------------------------------- */
* 1. PREPARING INDIVIDUAL-LEVEL WAGE DATA
* ---------------------------------------------------------------------------- *
	
	foreach year of num 2011/2023 {
		//  Starting point: monthly SPOLIS for 2010/2023; excluding directors, interns, 
		//  and wsw-ers; restricted to mainjobs
		spolisselect, data(month) start(`year') end(`year') jobtype(2) mainjob(1)
	
		// Merge GBA data (ethnic categories)
		sort rinpersoon
		merge 1:1 rinpersoon using "${dGBA}/gba_rin_2023", ///
			keep(master match) keepusing(rin_miggrp_cbs) nogen 
		
		// Merge ABR data (industry) 
		sort year beid
		merge m:1 year beid using "${dABR}/abr_ogbe_register_2006_2023", ///
			keep(match) keepusing(be_industry) nogen
		
		* Reduce variable set 
		keep rinpersoon beid sbasisloon_month sreguliereuren_month rin_miggrp_cbs ///
			be_industry
		
		// Construct hourly wage measure
		gen hwage = sbasisloon_month/sreguliereuren_month 
		drop sbasisloon_month sreguliereuren_month
		* Bottom-code negative wages
		replace hwage = 1 if hwage<1
		* Remove missings
		drop if hwage==.
		
		// Drop extraterritorial organizations
		drop if be_industry==21
		
		// Restrict to large organizations (N>=100)
		orgsizeselect, id(beid) min(100) n_org(1) select(1)
	
		// Create dummy Western / Non-western based on rin_miggrp_cbs
		// Western = EU + NOR + SWI + ISL + UK + AUS + USA + NZ + CA 
		gen rin_wstrn = 2
		replace rin_wstrn = 1 if rin_miggrp_cbs==5009 | rin_miggrp_cbs==5010 | ///
			rin_miggrp_cbs==7024 | rin_miggrp_cbs==5051 | rin_miggrp_cbs==5040 | ///
			rin_miggrp_cbs==6066 | rin_miggrp_cbs==5015 | rin_miggrp_cbs==7065 | ///
			rin_miggrp_cbs==6002 | rin_miggrp_cbs==5002 | rin_miggrp_cbs==6029 | ///
			rin_miggrp_cbs==7085 | rin_miggrp_cbs==9089 | rin_miggrp_cbs==6003 | ///
			rin_miggrp_cbs==5017 | rin_miggrp_cbs==6007 | rin_miggrp_cbs==7044 | ///
			rin_miggrp_cbs==7064 | rin_miggrp_cbs==7066 | rin_miggrp_cbs==6018 | ///
			rin_miggrp_cbs==7003 | rin_miggrp_cbs==6030 | rin_miggrp_cbs==7028 | ///
			rin_miggrp_cbs==7050 | rin_miggrp_cbs==7047 | rin_miggrp_cbs==6067 | ///
			rin_miggrp_cbs==5049 | rin_miggrp_cbs==6037 | rin_miggrp_cbs==5039 | ///
			rin_miggrp_cbs==6039 | rin_miggrp_cbs==6016 | rin_miggrp_cbs==6014 | ///
			rin_miggrp_cbs==5013 | rin_miggrp_cbs==5001 | rin_miggrp_cbs==6027 | ///
			rin_miggrp_cbs==6011 | rin_miggrp_cbs==5003 | rin_miggrp_cbs==5032 | ///
			rin_miggrp_cbs==5056 | rin_miggrp_cbs==5065 | rin_miggrp_cbs==6012 | ///
			rin_miggrp_cbs==6028 | rin_miggrp_cbs==9071 | rin_miggrp_cbs==6055 | ///
			rin_miggrp_cbs==7005 | rin_miggrp_cbs==7087 | rin_miggrp_cbs==8014 | ///
			rin_miggrp_cbs==8034 | rin_miggrp_cbs==8035 | rin_miggrp_cbs==7058 | ///
			rin_miggrp_cbs==9030
		
		gen wstrn = 0
		replace wstrn=1 if rin_wstrn==1
		gen nwstrn = 0
		replace nwstrn=1 if rin_wstrn==2
		drop rin_wstrn
		
		// Generate within-firm wage quantiles
		gquantiles withind = hwage, xtile nquantiles(10) by(beid)
		
		// Save dataset
		save "${wdir}/data/d/wages_`year'", replace
	}
	*
	
* --------------------------------------------------------------------------- */
* 2. DECILE SHARES (NOT WEIGHTED)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/d/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${dABR}/abr_ogbe_register_2006_2023", ///
			keepusing(og_sector_alt be_gksbs vep_legalform og_ownership be_lbe) ///
			nogen keep(match)
			
		merge m:1 beid year using "${dBDK}/bdk_be_2007_2023", ///
			keepusing(be_founding) nogen keep(master match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
			
		// Prepare LBE & Founding
		replace be_lbe = 2 if be_lbe>=2 & be_lbe<=4
		replace be_lbe = 3 if be_lbe>=5 & be_lbe!=.
		gen lbe = be_lbe
		
		gen foundy = year(be_founding)
		gen cohort = 0
		replace cohort=1 if foundy<1960
		replace cohort=2 if foundy>=1960 & foundy<1970
		replace cohort=3 if foundy>=1970 & foundy<1980
		replace cohort=4 if foundy>=1980 & foundy<1990
		replace cohort=5 if foundy>=1990 & foundy<2000
		replace cohort=6 if foundy>=2000 & foundy<2010
		replace cohort=7 if foundy>=2010 & foundy<2020
		replace cohort=8 if foundy>=2020 & foundy<=2023
		
		drop be_lbe foundy
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			gegen tot_nwstrn = mean(nwstrn)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
				n_org=n_org (sum) n = nwstrn, by(withind)
			drop if withind==.
			gen wstrn="Non-Western"
			save "${adir}/withinq_nwstrn", replace
		restore
		preserve
			gegen tot_nwstrn = mean(nwstrn)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
				n_org=n_org (sum) n = wstrn, by(withind)
			drop if withind==.
			gen wstrn="Western"
			append using "${adir}/withinq_nwstrn" 
			erase "${adir}/withinq_nwstrn.dta"
			sort withind wstrn
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
	
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if be_industry==`ind', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if be_industry==`ind', by(withind)
				gen wstrn="Western"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_19", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_nw_7" "${adir}/withinq_nw_8" ///
			"${adir}/withinq_nw_9" "${adir}/withinq_nw_10" ///
			"${adir}/withinq_nw_11" "${adir}/withinq_nw_12" ///
			"${adir}/withinq_nw_13" "${adir}/withinq_nw_14" ///
			"${adir}/withinq_nw_15" "${adir}/withinq_nw_16" ///
			"${adir}/withinq_nw_17" "${adir}/withinq_nw_18" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_w_19"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing" ///
				2"Industry: Mining and quarrying" ///
				3"Industry: Manufacturing" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities" ///
				6"Industry: Construction" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles" ///
				8"Industry: Transportation and storage" ///
				9"Industry: Accomodation and food service activities" ///
				10"Industry: Information and communication" ///
				11"Industry: Financial institutions" ///
				12"Industry: Renting, buying, and selling of real estate" ///
				13"Industry: Consultancy, research and other specialised business services" ///
				14"Industry: Renting and leasing of tangible goods and other business support services" ///
				15"Industry: Public administration, public services, and compulsory social security" ///
				16"Industry: Education" ///
				17"Industry: Human health and social work activities" ///
				18"Industry: Culture, sports, and recreation" ///
				19"Industry: Other service activities" ///
				20"Industry: Activities of households as employers" ///
				21"Industry: Extraterritorial organizations and bodies", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_nw_`ind'.dta"
				erase "${adir}/withinq_w_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if og_sector_alt==`sect'
				gunique beid if og_sector_alt==`sect'
				gen n_org=r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if og_sector_alt==`sect', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if og_sector_alt==`sect'
				gunique beid if og_sector_alt==`sect'
				gen n_org=r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if og_sector_alt==`sect', by(withind)
				gen wstrn="Western"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_15", replace
			append using "${adir}/withinq_nw_11" "${adir}/withinq_nw_12" ///
			"${adir}/withinq_nw_13" "${adir}/withinq_w_11" ///
			"${adir}/withinq_w_12" "${adir}/withinq_w_13" ///
			"${adir}/withinq_w_15"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def sect_lbl 11"Sector: Non-financial company" ///
				12"Sector: Financial organization" 13"Sector: Governmental organization" ///
				15"Sector: Non-governmental non-profit organization", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_nw_`sect'.dta"
				erase "${adir}/withinq_w_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 71 72 81 82 91 92 93 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if be_gksbs==`gksbs', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 71 72 81 82 91 92 93 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if be_gksbs==`gksbs', by(withind)
				gen wstrn="Western"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_93", replace
			append using "${adir}/withinq_nw_71" "${adir}/withinq_nw_72" ///
			"${adir}/withinq_nw_81" "${adir}/withinq_nw_82" ///
			"${adir}/withinq_nw_91" "${adir}/withinq_nw_92" ///
			"${adir}/withinq_w_71" "${adir}/withinq_w_72" ///
			"${adir}/withinq_w_81" "${adir}/withinq_w_82" ///
			"${adir}/withinq_w_91" "${adir}/withinq_w_92" ///
			"${adir}/withinq_w_93"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def gksbs_lbl 71 "Size: 100-149 employees" 72 "Size: 150-199 employees" ///
				81 "Size: 200-249 employees" 82 "Size: 250-499 employees" 91 "Size: 500-999 employees" ///
				92 "Size: 1000-1999 employees" 93 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 71 72 81 82 91 92 93 {
				erase "${adir}/withinq_nw_`gksbs'.dta"
				erase "${adir}/withinq_w_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if vep_legalform==`legal', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if vep_legalform==`legal', by(withind)
				gen wstrn="Western"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_900", replace
			append using "${adir}/withinq_nw_43" "${adir}/withinq_nw_57" ///
			"${adir}/withinq_nw_74" ///
			"${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" "${adir}/withinq_w_900"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Verschillende publiekrechtelijke instellingen", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_nw_`legal'.dta"
				erase "${adir}/withinq_w_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if og_ownership==`owner', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if og_ownership==`owner', by(withind)
				gen wstrn="Western"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_3", replace
			append using "${adir}/withinq_nw_2" ///
			"${adir}/withinq_w_2" "${adir}/withinq_w_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def owner_lbl 2 "Ownership: Domestic" 3 "Ownership: Foreign", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_nw_`owner'.dta"
				erase "${adir}/withinq_w_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if cao==`cao', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if cao==`cao', by(withind)
				gen wstrn="Western"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_2", replace
			append using "${adir}/withinq_nw_0" ///
			"${adir}/withinq_nw_1" "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cao_lbl 0 "CAO: No collective agreement " 1 "CAO: Sectoral agreement" ///
				2 "CAO: Firm-level agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_nw_`cao'.dta"
				erase "${adir}/withinq_w_`cao'.dta"	
			}
			*
		restore
		
		**************
		* By number of LBEs
		**************
		foreach lbe of num 1 2 3 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if lbe==`lbe'
				gunique beid if lbe==`lbe'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if lbe==`lbe', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`lbe'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`lbe'", replace
			restore		
		}
		*
		foreach lbe of num 1 2 3 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if lbe==`lbe'
				gunique beid if lbe==`lbe'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if lbe==`lbe', by(withind)
				gen wstrn="Western"
				gen subpop=`lbe'
				order subpop, before(withind)
				save "${adir}/withinq_w_`lbe'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_3", replace
			append using "${adir}/withinq_nw_1" ///
			"${adir}/withinq_nw_2" "${adir}/withinq_w_1" ///
			"${adir}/withinq_w_2" "${adir}/withinq_w_3"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def lbe_lbl 1 "Nr. of establishments: 1" 2 "Nr. of establishments: 2-4" ///
				3 "Nr. of establishments: 5+", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_lbe_`year'", replace
	
			foreach lbe of num 1 2 3 {
				erase "${adir}/withinq_nw_`lbe'.dta"
				erase "${adir}/withinq_w_`lbe'.dta"	
			}
			*
		restore
		
		**************
		* By founding cohort
		**************
		if `year'<=2019 {
		foreach cohort of num 1/7 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if cohort==`cohort', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/7 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if cohort==`cohort', by(withind)
				gen wstrn="Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_7", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/7 {
				erase "${adir}/withinq_nw_`cohort'.dta"
				erase "${adir}/withinq_w_`cohort'.dta"	
			}
			*
		restore
		}
		else {
		foreach cohort of num 1/8 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=nwstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = nwstrn if cohort==`cohort', by(withind)
				gen wstrn="Non-Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/8 {
			preserve
				gegen tot_nwstrn = mean(nwstrn) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=wstrn (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = wstrn if cohort==`cohort', by(withind)
				gen wstrn="Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_8", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_nw_7" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/8 {
				erase "${adir}/withinq_nw_`cohort'.dta"
				erase "${adir}/withinq_w_`cohort'.dta"	
			}
			*
		restore
		}
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withind)
			save "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withind_`var'", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
* --------------------------------------------------------------------------- */
* 3. DECILE SHARES (WEIGHTED BY FIRM SIZE)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/d/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${dABR}/abr_ogbe_register_2006_2023", ///
			keepusing(og_sector_alt be_gksbs vep_legalform og_ownership be_lbe) ///
			nogen keep(match)
			
		merge m:1 beid year using "${dBDK}/bdk_be_2007_2023", ///
			keepusing(be_founding) nogen keep(master match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
			
		// Prepare LBE & Founding
		replace be_lbe = 2 if be_lbe>=2 & be_lbe<=4
		replace be_lbe = 3 if be_lbe>=5 & be_lbe!=.
		gen lbe = be_lbe
		
		gen foundy = year(be_founding)
		gen cohort = 0
		replace cohort=1 if foundy<1960
		replace cohort=2 if foundy>=1960 & foundy<1970
		replace cohort=3 if foundy>=1970 & foundy<1980
		replace cohort=4 if foundy>=1980 & foundy<1990
		replace cohort=5 if foundy>=1990 & foundy<2000
		replace cohort=6 if foundy>=2000 & foundy<2010
		replace cohort=7 if foundy>=2010 & foundy<2020
		replace cohort=8 if foundy>=2020 & foundy<=2023
		
		drop be_lbe foundy
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			collapse (mean) share_be=nwstrn (sum) n = nwstrn, by(beid withind)
			gegen tot_nwstrn = mean(share_be)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
				n_org=n_org (sum) n = n, by(withind)
			gen wstrn="Non-Western"
			save "${adir}/withinq_nwstrn", replace
		restore
		preserve
			collapse (mean) share_be=wstrn (sum) n = wstrn, by(beid withind)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
			drop if withind==.
			gen wstrn="Western"
			append using "${adir}/withinq_nwstrn"
			egen tnw = max(tot_nwstrn)
			drop tot_nwstrn
			rename tnw tot_nwstrn
			erase "${adir}/withinq_nwstrn.dta"
			sort withind wstrn
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
		
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if be_industry==`ind', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if be_industry==`ind', by(beid withind)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`ind'
				order subpop, before(withind)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_19", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_nw_7" "${adir}/withinq_nw_8" ///
			"${adir}/withinq_nw_9" "${adir}/withinq_nw_10" ///
			"${adir}/withinq_nw_11" "${adir}/withinq_nw_12" ///
			"${adir}/withinq_nw_13" "${adir}/withinq_nw_14" ///
			"${adir}/withinq_nw_15" "${adir}/withinq_nw_16" ///
			"${adir}/withinq_nw_17" "${adir}/withinq_nw_18" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_w_19"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing" ///
				2"Industry: Mining and quarrying" ///
				3"Industry: Manufacturing" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities" ///
				6"Industry: Construction" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles" ///
				8"Industry: Transportation and storage" ///
				9"Industry: Accomodation and food service activities" ///
				10"Industry: Information and communication" ///
				11"Industry: Financial institutions" ///
				12"Industry: Renting, buying, and selling of real estate" ///
				13"Industry: Consultancy, research and other specialised business services" ///
				14"Industry: Renting and leasing of tangible goods and other business support services" ///
				15"Industry: Public administration, public services, and compulsory social security" ///
				16"Industry: Education" ///
				17"Industry: Human health and social work activities" ///
				18"Industry: Culture, sports, and recreation" ///
				19"Industry: Other service activities" ///
				20"Industry: Activities of households as employers" ///
				21"Industry: Extraterritorial organizations and bodies", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_nw_`ind'.dta"
				erase "${adir}/withinq_w_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if og_sector_alt==`sect', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if og_sector_alt==`sect', by(beid withind)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`sect'
				order subpop, before(withind)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_15", replace
			append using "${adir}/withinq_nw_11" "${adir}/withinq_nw_12" ///
			"${adir}/withinq_nw_13" "${adir}/withinq_w_11" ///
			"${adir}/withinq_w_12" "${adir}/withinq_w_13" ///
			"${adir}/withinq_w_15"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def sect_lbl 11"Sector: Non-financial company" ///
				12"Sector: Financial organization" 13"Sector: Governmental organization" ///
				15"Sector: Non-governmental non-profit organization", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_nw_`sect'.dta"
				erase "${adir}/withinq_w_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 71 72 81 82 91 92 93 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if be_gksbs==`gksbs', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 71 72 81 82 91 92 93 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if be_gksbs==`gksbs', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`gksbs'
				order subpop, before(withind)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_93", replace
			append using "${adir}/withinq_nw_71" "${adir}/withinq_nw_72" ///
			"${adir}/withinq_nw_81" "${adir}/withinq_nw_82" ///
			"${adir}/withinq_nw_91" "${adir}/withinq_nw_92" ///
			"${adir}/withinq_w_71" "${adir}/withinq_w_72" ///
			"${adir}/withinq_w_81" "${adir}/withinq_w_82" ///
			"${adir}/withinq_w_91" "${adir}/withinq_w_92" ///
			"${adir}/withinq_w_93"
			
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def gksbs_lbl 71 "Size: 100-149 employees" 72 "Size: 150-199 employees" ///
				81 "Size: 200-249 employees" 82 "Size: 250-499 employees" 91 "Size: 500-999 employees" ///
				92 "Size: 1000-1999 employees" 93 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 71 72 81 82 91 92 93 {
				erase "${adir}/withinq_nw_`gksbs'.dta"
				erase "${adir}/withinq_w_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if vep_legalform==`legal', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if vep_legalform==`legal', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`legal'
				order subpop, before(withind)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_900", replace
			append using "${adir}/withinq_nw_43" "${adir}/withinq_nw_57" ///
			"${adir}/withinq_nw_74" ///
			"${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" "${adir}/withinq_w_900"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Verschillende publiekrechtelijke instellingen", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_nw_`legal'.dta"
				erase "${adir}/withinq_w_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if og_ownership==`owner', by(beid withind)
				gegen tot_nwstrn = mean(share_be) 
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if og_ownership==`owner', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`owner'
				order subpop, before(withind)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_3", replace
			append using "${adir}/withinq_nw_2" ///
			"${adir}/withinq_w_2" "${adir}/withinq_w_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def owner_lbl 2 "Ownership: Domestic" 3 "Ownership: Foreign", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_nw_`owner'.dta"
				erase "${adir}/withinq_w_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if cao==`cao', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western" 
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if cao==`cao', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`cao'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_2", replace
			append using "${adir}/withinq_nw_0" ///
			"${adir}/withinq_nw_1" "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cao_lbl 0 "CAO: No collective agreement " 1 "CAO: Sectoral agreement" ///
				2 "CAO: Firm-level agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_nw_`cao'.dta"
				erase "${adir}/withinq_w_`cao'.dta"	
			}
			*
		restore
		
		**************
		* By number of LBEs
		**************
		foreach lbe of num 1 2 3 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if lbe==`lbe', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western" 
				gen subpop=`lbe'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`lbe'", replace
			restore		
		}
		*
		foreach lbe of num 1 2 3 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if lbe==`lbe', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`lbe'
				order subpop, before(withind)
				save "${adir}/withinq_w_`lbe'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_3", replace
			append using "${adir}/withinq_nw_1" ///
			"${adir}/withinq_nw_2" "${adir}/withinq_w_1" ///
			"${adir}/withinq_w_2" "${adir}/withinq_w_3"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def lbe_lbl 1 "Nr. of establishments: 1" 2 "Nr. of establishments: 2-4" ///
				3 "Nr. of establishments: 5+", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_lbe_`year'", replace
	
			foreach lbe of num 1 2 3 {
				erase "${adir}/withinq_nw_`lbe'.dta"
				erase "${adir}/withinq_w_`lbe'.dta"	
			}
			*
		restore
		
		**************
		* By foundation cohort
		**************
		if `year'<=2019 {
		foreach cohort of num 1/7 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if cohort==`cohort', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western" 
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/7 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if cohort==`cohort', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_7", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/7 {
				erase "${adir}/withinq_nw_`cohort'.dta"
				erase "${adir}/withinq_w_`cohort'.dta"	
			}
			*
		restore
		}
		else {
		foreach cohort of num 1/8 {
			preserve
				collapse (mean) share_be=nwstrn (sum) n = nwstrn if cohort==`cohort', by(beid withind)
				gegen tot_nwstrn = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_nwstrn=tot_nwstrn ///
					n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Non-Western" 
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_nw_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/8 {
			preserve
				collapse (mean) share_be=wstrn (sum) n = wstrn if cohort==`cohort', by(beid withind)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withind)
				gen wstrn="Western"
				gen subpop=`cohort'
				order subpop, before(withind)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_nw_8", replace
			append using "${adir}/withinq_nw_1" "${adir}/withinq_nw_2" ///
			"${adir}/withinq_nw_3" "${adir}/withinq_nw_4" ///
			"${adir}/withinq_nw_5" "${adir}/withinq_nw_6" ///
			"${adir}/withinq_nw_7" ///
			"${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8"
	
			gen pc = round((share*100),.01)
			
			drop if withind==.
			sort subpop withind wstrn
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/8 {
				erase "${adir}/withinq_nw_`cohort'.dta"
				erase "${adir}/withinq_w_`cohort'.dta"	
			}
			*
		restore
		}
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withind)
			save  "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withind_`var'_weighted", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
	* Fill missing of total average share of non-western across quintiles
	foreach var in industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withind_`var'_weighted", replace
		
		egen tnw = max(tot_nwstrn), by(subpop year)
		replace tot_nwstrn = tnw if tot_nwstrn==.
		drop tnw 
		
		save "${adir}/withind_`var'_weighted", replace
	}
	*
	
	
* --------------------------------------------------------------------------- */
* 4. COMBINE FILES
* ---------------------------------------------------------------------------- *

	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withind_`var'", replace
		
		gen wgt = "No"
		order wgt, before(year)
		capture order wgt, before(subpop)
		
		append using "${adir}/withind_`var'_weighted"
		
		replace wgt = "Yes" if wgt==""
		
		save "${adir}/withind_`var'", replace
		
		erase "${adir}/withind_`var'_weighted.dta"
	
	}
	*
	
	* Generate percentage variable for tot_nwstrn
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withind_`var'", replace
		gen pc_tnw = round((tot_nwstrn*100),.01)
		
		save "${adir}/withind_`var'", replace
	}
	*
	
	* Save subpop variable as string
	foreach var in industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withind_`var'", replace
		decode subpop, gen(_subpop)
		drop subpop
		rename _subpop subpop
		
		save "${adir}/withind_`var'", replace
	}
	*
	
	*Combine in one file
	use "${adir}/withind_all", replace
	generate subpop = "Total population of larger organizations"
	
	append using "${adir}/withind_industry" ///
		"${adir}/withind_sector" ///
		"${adir}/withind_gksbs" ///
		"${adir}/withind_legal" ///
		"${adir}/withind_owner" ///
		"${adir}/withind_cao" ///
		"${adir}/withind_lbe" ///
		"${adir}/withind_cohort"
	
	generate format = "Wage deciles"
	
	order subpop, after(year)
	order format, before(wgt)
	
	save "${adir}/withind_ethnicity", replace
		
	export excel using "${adir}/withind_ethnicity", firstrow(variables) replace
	
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		erase "${adir}/withind_`var'.dta"
	}
	*
	