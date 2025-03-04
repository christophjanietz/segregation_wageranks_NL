### Dashboard of segregation across wage ranks in Dutch organizations. 
### Christoph Janietz (University of Groningen) 
### Current version: March 2025.

# Libraries and functions ------------------------------------------------------
library(shiny)
library(shinythemes)
library(dplyr)
library(stringr)
library(ggplot2)
library(scales)

kandinsky2 <- c("#3b7c70", "#ce9642")
isfahan2 <- c("#e3c28b", "#178f92")

f <- function (x) {format(x, big.mark=',')}
url <- "https://bsky.app/intent/compose?text=Sex%20and%20ethnic%20segregation%20across%20wage%20ranks%20in%20Dutch%20organizations%20https://beyondboardrooms.shinyapps.io/segregation_wageranks_NL/"
url2 <- "https://github.com/christophjanietz/segregation_wageranks_NL"
url3 <- "https://osf.io/sak3d/"
options(scipen=999)

# Load data --------------------------------------------------------------------
load('./data/seg_org.RData')

# User interface (UI) ----------------------------------------------------------
ui <- fluidPage(theme = shinytheme("simplex"),
  ## Slider modification -------------------------------------------------------
  tags$head(tags$style(type='text/css', ".slider-animate-button { font-size: 20pt !important; }")),
  tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
  
  ## Dashboard title -----------------------------------------------------------
  titlePanel(windowTitle = 'Sex and ethnic segregation in Dutch organizations',
             title = fluidRow(
               column(10, strong("Sex and ethnic segregation across wage ranks in Dutch organizations, 2011-2023,"), (" based on microdata from"), a(href='https://www.cbs.nl/en-gb/our-services/customised-services-microdata/microdata-conducting-your-own-research', "Statistics Netherland (CBS)")), 
               column(2, div(img(height = 0.8*100, width = 0.8*130, src = "rug_logo.png", class = "pull-right")))
             )
  ),
  ## Sidebar layout ------------------------------------------------------------
  sidebarLayout(
    ## User interface panel ----------------------------------------------------
    sidebarPanel(width=3,
                 radioButtons(inputId = 'qd',
                              label = h4("Wage ranks:"),
                              choices = list("Wage quintiles (organizations with 50+ employees)" = "Wage quintiles",
                                             "Wage deciles (organizations with 100+ employees)" = "Wage deciles")),
                 p(),
                 hr(), 
                 helpText(h4("Weighting:")),
                 checkboxInput(inputId='wgt', 
                               label='Normalize by organization size', value = FALSE),
                 p(),
                 hr(), 
                 sliderInput(inputId="years", 
                             label=h4("Select year:"),
                             min = 2011, max = 2023,
                             value = 2011, step=1, sep='',
                             animate=TRUE),
                 hr(), 
                 helpText(h4("Select organizational (sub)population:")),
                 selectInput(inputId='subpop', label='',
                              c("Total population of large organizations" = "Total population of large organizations",
                                "Industry: Agriculture, forestry, and fishing (SBI08 A)" = "Industry: Agriculture, forestry, and fishing (SBI08 A)",
                                "Industry: Mining and quarrying (SBI08 B)" = "Industry: Mining and quarrying (SBI08 B)",
                                "Industry: Manufacturing (SBI08 C)" = "Industry: Manufacturing (SBI08 C)",
                                "Industry: Electricity, gas, steam, and air conditioning supply (SBI08 D)" = "Industry: Electricity, gas, steam, and air conditioning supply (SBI08 D)",
                                "Industry: Water supply; sewerage, waste management and remidiation activities (SBI08 E)" = "Industry: Water supply; sewerage, waste management and remidiation activities (SBI08 E)",
                                "Industry: Construction (SBI08 F)" = "Industry: Construction (SBI08 F)",
                                "Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles (SBI08 G)" = "Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles (SBI08 G)",
                                "Industry: Transportation and storage (SBI08 H)" = "Industry: Transportation and storage (SBI08 H)",
                                "Industry: Accomodation and food service activities (SBI08 I)" = "Industry: Accomodation and food service activities (SBI08 I)",
                                "Industry: Information and communication (SBI08 J)" = "Industry: Information and communication (SBI08 J)",
                                "Industry: Financial institutions (SBI08 K)" = "Industry: Financial institutions (SBI08 K)",
                                "Industry: Renting, buying, and selling of real estate (SBI08 L)" = "Industry: Renting, buying, and selling of real estate (SBI08 L)",
                                "Industry: Consultancy, research and other specialised business services (SBI08 M)" = "Industry: Consultancy, research and other specialised business services (SBI08 M)",
                                "Industry: Renting and leasing of tangible goods and other business support services (SBI08 N)" = "Industry: Renting and leasing of tangible goods and other business support services (SBI08 N)",
                                "Industry: Public administration, public services, and compulsory social security (SBI08 O)" = "Industry: Public administration, public services, and compulsory social security (SBI08 O)",
                                "Industry: Education (SBI08 P)" = "Industry: Education (SBI08 P)",
                                "Industry: Human health and social work activities (SBI08 Q)" = "Industry: Human health and social work activities (SBI08 Q)",
                                "Industry: Culture, sports, and recreation (SBI08 R)" = "Industry: Culture, sports, and recreation (SBI08 R)",
                                "Industry: Other service activities (SBI08 S)" = "Industry: Other service activities (SBI08 S)",
                                "Sector: Non-financial companies" = "Sector: Non-financial companies",
                                "Sector: Financial organizations" = "Sector: Financial organizations",
                                "Sector: Governmental organizations" = "Sector: Governmental organizations",
                                "Sector: Non-governmental non-profit organizations" = "Sector: Non-governmental non-profit organizations",
                                "Ownership: Domestic non-financial companies" = "Ownership: Domestic non-financial companies",
                                "Ownership: Foreign non-financial companies" = "Ownership: Foreign non-financial companies",
                                "Legal type: Besloten Vennootschap (bv)" = "Legal type: Besloten Vennootschap (bv)",
                                "Legal type: Naamloze Vennootschap (nv)" = "Legal type: Naamloze Vennootschap (nv)",
                                "Legal type: Stichting" = "Legal type: Stichting",
                                "Legal type: Publiekrechtelijke instelling" = "Legal type: Publiekrechtelijke instelling",
                                "CAO: Sector-level collective agreement" = "CAO: Sector-level collective agreement",
                                "CAO: Firm-level collective agreement" = "CAO: Firm-level collective agreement",
                                "CAO: No collective agreement" = "CAO: No collective agreement",
                                "Size: 50-99 employees" = "Size: 50-99 employees",
                                "Size: 100-149 employees" = "Size: 100-149 employees",
                                "Size: 150-199 employees" = "Size: 150-199 employees",
                                "Size: 200-249 employees" = "Size: 200-249 employees",
                                "Size: 250-499 employees" = "Size: 250-499 employees",
                                "Size: 500-999 employees" = "Size: 500-999 employees",
                                "Size: 1000-1999 employees" = "Size: 1000-1999 employees",
                                "Size: 2000+ employees" = "Size: 2000+ employees",
                                "Nr. of establishments: 1" = "Nr. of establishments: 1",
                                "Nr. of establishments: 2-4" = "Nr. of establishments: 2-4",
                                "Nr. of establishments: 5+" = "Nr. of establishments: 5+",
                                "Founding cohort: -1960" = "Founding cohort: -1960",
                                "Founding cohort: 1960s" = "Founding cohort: 1960s",
                                "Founding cohort: 1970s" = "Founding cohort: 1970s",
                                "Founding cohort: 1980s" = "Founding cohort: 1980s",
                                "Founding cohort: 1990s" = "Founding cohort: 1990s",
                                "Founding cohort: 2000s" = "Founding cohort: 2000s",
                                "Founding cohort: 2010s" = "Founding cohort: 2010s",
                                "Founding cohort: 2020s" = "Founding cohort: 2020s"),
                              selected = 'Total population of large organizations'),
                 p(),
                 hr(), 
                 # Buttons
                 downloadButton("save",  "Sex segregation plot"),
                 hr(),
                 downloadButton("save2", "Ethnic segregation plot"), 
                 p(),
                 hr(),
                 helpText(h4("Share & Code:")),
                 actionButton("bluesky_share",
                              label = "Share",
                              icon = icon("share-nodes"),
                              onclick = sprintf("window.open('%s')", url)),
                 
                actionButton("github_link",
                              label = "Code",
                              icon = icon("github"),
                              onclick = sprintf("window.open('%s')", url2)),
                 
                 actionButton("osf_link",
                              label = "OSF",
                              icon = icon("atom"),
                              onclick = sprintf("window.open('%s')", url3)),
                 p(),
                 bookmarkButton(id = "bookmark1", label='Bookmark'),
                 hr()
    ),
    ## Structure of the main panel ---------------------------------------------
    mainPanel(width=9,
              tabsetPanel(
                tabPanel("Sex segregation",
                  fluidRow(
                  plotOutput("splot", width = "100%", height = 700)
                  ),
                  hr(),
                  htmlOutput("notes"),
                  hr(),
                  htmlOutput("colophon"),
                  hr()),
                tabPanel("Ethnic segregation",
                  fluidRow(
                  plotOutput("eplot", width = "100%", height = 700)
                  ),
                  hr(),
                  htmlOutput("notes2"),
                  hr(),
                  htmlOutput("colophon2"),
                  hr()))
    )  
  )
)

# Server side ------------------------------------------------------------------
server <- function(input, output, session) {
  setBookmarkExclude(c("bookmark1"))
  observeEvent(input$bookmark1, {session$doBookmark()})
  
  # Get the user inputs in variables -------------------------------------------
  qd_u <- reactive({input$qd})
  wgt_u <- reactive({input$wgt})
  year_u <- reactive({input$years})
  subpop_u <- reactive({input$subpop})
  
  # Subset the data based on the user input ------------------------------------
  s_data <- reactive ({
    s <- sexseg %>%
      dplyr::filter(format==qd_u() & wgt==wgt_u() & year==year_u() & subpop==subpop_u()) %>% 
      dplyr::select (format, wgt, subpop, year, rank, share, tot_woman, n_org, sex, pc, pc_tw) %>% 
      data.frame()
    s
  })
  e_data <- reactive ({
    e <- ethnicseg %>%
      dplyr::filter(format==qd_u() & wgt==wgt_u() & year==year_u() & subpop==subpop_u()) %>% 
      dplyr::select (format, wgt, subpop, year, rank, share, tot_nwstrn, n_org, wstrn, pc, pc_tnw) %>% 
      data.frame()
    e
  })
  
  # Plot I: Sex segregation ----------------------------------------------------
  plotInput <- function(){
    ggplot(s_data(), aes(y=share, x=rank, fill=sex, label=round(pc, digits=2))) +
      geom_bar(position = "fill", stat = "identity") +
      geom_text(size = 5, position = position_stack(vjust=0.5)) +
      geom_hline(aes(yintercept = tot_woman), linewidth=0.75) +
      scale_x_continuous(breaks = seq(1,10,1)) +
      scale_y_continuous(breaks = seq(0,1,0.2), labels = scales::percent) +
      scale_fill_manual(values = kandinsky2) +
      facet_wrap(~ subpop) +
      labs(x = paste0("Within-organization wage ranks in ", year_u(), "\n (",s_data()$n_org[1]," organizations with ", (max(s_data()$rank)*10), "+ employees)"),
           y = "%", fill = "") +
      theme_minimal() +
      theme(legend.position = "bottom",
            strip.text.x = element_text(size = 20),
            axis.text = element_text(size = 15),
            axis.title = element_text(size = 15),
            legend.text = element_text(size = 15))
  }
  
  # Plot II: Ethnic segregation ------------------------------------------------
  plotInput2 <- function(){
    ggplot(e_data(), aes(y=share, x=rank, fill=wstrn, label=round(pc, digits=2))) +
      geom_bar(position = "fill", stat = "identity") +
      geom_text(size = 5, position = position_stack(vjust=0.5)) +
      geom_hline(aes(yintercept = tot_nwstrn), linewidth=0.75) +
      scale_x_continuous(breaks = seq(1,10,1)) +
      scale_y_continuous(breaks = seq(0,1,0.2), labels = scales::percent) +
      scale_fill_manual(values = isfahan2) +
      facet_wrap(~ subpop) +
      labs(x = paste0("Within-organization wage ranks in ", year_u(), "\n (",e_data()$n_org[1]," organizations with ", (max(s_data()$rank)*10), "+ employees)"),
           y = "%", fill = "") +
      theme_minimal() +
      theme(legend.position = "bottom",
            strip.text.x = element_text(size = 20),
            axis.text = element_text(size = 15),
            axis.title = element_text(size = 15),
            legend.text = element_text(size = 15))
    }
  
  # Print plots I (Sex segregation) and II (Ethnic segregation)-----------------
  output$splot <- renderPlot({print(plotInput())})
  output$eplot <- renderPlot({print(plotInput2())})
  
  # Text: Notes I --------------------------------------------------------------
  output$notes <- renderText({ 
    paste('<strong>Notes:</strong> This figure visualizes sex segregation of wage earners across wage ranks within Dutch organizations. The underlying population are all wage earners (excluding interns, WSW-ers, and DGAs) in Dutch organizations with at least 50 (100) employees during the month of September. 
          Calculations are based on administrative linked employer-employee register data <a target="_blank" href="https://www.cbs.nl/nl-nl/onze-diensten/maatwerk-en-microdata/microdata-zelf-onderzoek-doen/microdatabestanden/spolisbus-banen-en-lonen-volgens-polisadministratie">(SPOLIS)</a> covering the entire underlying population. 
          Sex categories are based on the binary administrative sex classification in the Basisregistratie Personen <a target="_blank" href="https://www.rijksoverheid.nl/onderwerpen/privacy-en-persoonsgegevens/basisregistratie-personen-brp">(BRP)</a>.
          Wage ranks are assigned to employees using the organization-specific distribution of hourly wages in September of a given year. 
          The first wage rank comprises the bottom 20% (10%) of wage earners, whereas the last wage rank comprises the top 20% (10%) of wage earners in each organization. 
          The overall share of men and women per wage rank can be calculated in two ways: (1) at the individual level (with larger organizations contributing more strongly to the total) or (2) normalized by organization size (all organizations contribute equally to the total (i.e. firm-level average)).
          Calculations can be further refined along the dimensions of specific organizational characteristics. The reference line depicts the overall share of women across all wage ranks in the selected organizations.')
  })
  
  # Text: Notes II -------------------------------------------------------------
  output$notes2 <- renderText({ 
    paste('<strong>Notes:</strong> This figure visualizes ethnic segregation of wage earners across wage ranks within Dutch organizations. The underlying population are all wage earners (excluding interns, WSW-ers, and DGAs) in Dutch organizations with at least 50 (100) employees during the month of September. 
          Calculations are based on administrative linked employer-employee register data <a target="_blank" href="https://www.cbs.nl/nl-nl/onze-diensten/maatwerk-en-microdata/microdata-zelf-onderzoek-doen/microdatabestanden/spolisbus-banen-en-lonen-volgens-polisadministratie">(SPOLIS)</a> covering the entire underlying population.
          Ethnic categories are constructed based on the country of birth of the employees and their parents as registered in the Basisregistratie Personen <a target="_blank" href="https://www.rijksoverheid.nl/onderwerpen/privacy-en-persoonsgegevens/basisregistratie-personen-brp">(BRP)</a>.
          Following CBS procedures, categories are based on the country of birth of the employee, if born outside the Netherlands (1st generation), or the country of birth of their mother, if born in the Netherlands (2nd generation). The countries classified as "western" are all EU membership countries, Iceland, Norway, Switzerland, UK, USA, Canada, Australia, New Zealand.
          Wage ranks are assigned to employees using the organization-specific distribution of hourly wages in September of a given year.
          The first wage rank comprises the bottom 10% of wage earners, whereas the last wage rank comprises the top 20% (10%) of wage earners in each organization. 
          The overall share of employees with western and non-western descent per wage rank can be calculated in two ways: (1) at the individual level (with larger organizations contributing more strongly to the total) or (2) normalized by organization size (all organizations contribute equally to the total (i.e. firm-level average)).
          Calculations can be further refined along the dimensions of specific organizational characteristics. The reference line depicts the overall share of employees with non-western descent across all wage ranks in the selected organizations.')
  })
  
  # Text: Colophon I -----------------------------------------------------------
  output$colophon <- renderText({ 
    paste('<strong>Colophon:</strong> This dashboard was created by <a target="_blank" href="https://christophjanietz.github.io">Christoph Janietz</a> with <code>R</code>, <code>RStudio</code> and <code>Shiny</code>. 
        This dashboard uses non-public microdata from Statistics Netherlands (CBS). Under certain conditions, these microdata are accessible for statistical and scientific research. For further information: <a target="_blank" href = "mailto:microdata@cbs.nl">microdata@cbs.nl</a>.
        Data is prepared and analyzed using <code>NIDIO</code> - an open code infrastructure assisting with the use of Dutch administrative register data <a target="_blank" href="https://osf.io/9b2xh/">(https://osf.io/9b2xh/)</a>.
        Contact me <a target="_blank" href = "mailto:c.janietz@rug.nl?subject = Feedback&body = Message">here</a> for questions or suggestions. Last update: March 2025.')
  })
  
  # Text: Colophon II ----------------------------------------------------------
  output$colophon2 <- renderText({ 
    paste('<strong>Colophon:</strong> This dashboard was created by <a target="_blank" href="https://christophjanietz.github.io">Christoph Janietz</a> with <code>R</code>, <code>RStudio</code> and <code>Shiny</code>. 
        This dashboard uses non-public microdata from Statistics Netherlands (CBS). Under certain conditions, these microdata are accessible for statistical and scientific research. For further information: <a target="_blank" href = "mailto:microdata@cbs.nl">microdata@cbs.nl</a>.
        Data is prepared and analyzed using <code>NIDIO</code> - an open code infrastructure assisting with the use of Dutch administrative register data <a target="_blank" href="https://osf.io/9b2xh/">(https://osf.io/9b2xh/)</a>.
        Contact me <a target="_blank" href = "mailto:c.janietz@rug.nl?subject = Feedback&body = Message">here</a> for questions or suggestions. Last update: March 2025.')
  })
  
  # Download handlers ----------------------------------------------------------
  output$save <- downloadHandler(
    file = "sexsegregation_plot.pdf", 
    content = function(file) {
      ggsave(file,plot=plotInput(), width = 18, height = 12, units = "in")
    }) 
  
  output$save2 <- downloadHandler(
    file = "ethnicsegregation_plot.pdf" , 
    content = function(file) {
      ggsave(file,plot=plotInput2(), width = 18, height = 12, units = "in")
    })    

} 

# Run the app ------------------------------------------------------------------
enableBookmarking(store = "url")
shinyApp(ui, server)
