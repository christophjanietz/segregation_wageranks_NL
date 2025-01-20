### Dashboard of sex segregation across wage ranks in Dutch organizations. 
### Christoph Janietz (University of Groningen) 
### First version: January 2025.

# Libraries and functions ------------------------------------------------------
library(shiny)
library(shinythemes)
library(dplyr)
library(stringr)
library(ggplot2)
library(scales)

kandinsky2 <- c("#3b7c70", "#ce9642")

f <- function (x) {format(x, big.mark=',')}
url <- "https://bsky.app/intent/compose?text=Sex%20segregation%20across%20wage%20ranks%20in%20Dutch%20organizations%20https://cjanietz.shinyapps.io/sexsegregation_wageranks_NL/"
url2 <- "https://github.com/christophjanietz/sexsegregation_wageranks_NL"
url3 <- "https://osf.io/sak3d/"
options(scipen=999)

# Load data --------------------------------------------------------------------
load('./data/sexseg_org.RData')

# User interface (UI) ----------------------------------------------------------
ui <- fluidPage(theme = shinytheme("simplex"),
  ## Slider modification -------------------------------------------------------
  tags$head(tags$style(type='text/css', ".slider-animate-button { font-size: 20pt !important; }")),
  tags$style(type = "text/css", ".irs-grid-pol.small {height: 0px;}"),
  
  ## Dashboard title -----------------------------------------------------------
  titlePanel(windowTitle = 'Sex segregation in Dutch organizations',
             title = fluidRow(
               column(10, strong("Sex segregation across wage ranks in Dutch organizations, 2011-2023,"), (" based on microdata from"), a(href='https://www.cbs.nl/en-gb/our-services/customised-services-microdata/microdata-conducting-your-own-research', "Statistics Netherland (CBS)")), 
               column(2, div(img(height = 0.8*100, width = 0.8*130, src = "rug_logo.png", class = "pull-right")))
             )
  ),
  ## Sidebar layout ------------------------------------------------------------
  sidebarLayout(
    ## User interface panel ----------------------------------------------------
    sidebarPanel(width=3,
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
                                "Legal type: Besloten veenootschap (bv)" = "Legal type: Besloten veenootschap (bv)",
                                "Legal type: Naamloze vennootschap (nv)" = "Legal type: Naamloze vennootschap (nv)",
                                "Legal type: Stichting" = "Legal type: Stichting",
                                "Legal type: Publiekrichtelijke instelling" = "Legal type: Publiekrichtelijke instelling",
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
                                "Size: 2000+ employees" = "Size: 2000+ employees"),
                              selected = 'Total population of large organizations'),
                 p(),
                 hr(), 
                 # Buttons
                 downloadButton("save",  "Wage quintile plot"),
                 hr(),
                 downloadButton("save2", "Wage decile plot"), 
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
    ## Main panel ------------------------------------------------------------
    mainPanel(width=9,
              tabsetPanel(
                tabPanel("Wage quintiles",
                  fluidRow(
                  plotOutput("quintileplot", width = "100%", height = 700)
                  ),
                  hr(),
                  htmlOutput("notes"),
                  hr(),
                  htmlOutput("colophon"),
                  hr()),
                tabPanel("Wage deciles",
                  fluidRow(
                  plotOutput("decileplot", width = "100%", height = 700)
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
  
  # User input as variables ----------------------------------------------------
  wgt_u <- reactive({input$wgt})
  year_u <- reactive({input$years})
  subpop_u <- reactive({input$subpop})
  
  # Subset data based on user input --------------------------------------------
  q_data <- reactive ({
    q <- withinq %>%
      dplyr::filter(wgt==wgt_u() & year==year_u() & subpop==subpop_u()) %>% 
      dplyr::select (wgt, subpop, year, withinq, share, tot_woman, n_org, sex, pc, pc_tw) %>% 
      data.frame()
    q
  })
  d_data <- reactive ({
    d <- withind %>%
      dplyr::filter(wgt==wgt_u() & year==year_u() & subpop==subpop_u()) %>% 
      dplyr::select (wgt, subpop, year, withind, share, tot_woman, n_org, sex, pc, pc_tw) %>% 
      data.frame()
    d
  })
  
  # Plot I: Wage quintiles -----------------------------------------------------
  plotInput <- function(){
    ggplot(q_data(), aes(y=share, x=withinq, fill=sex, label=round(pc, digits=2))) +
      geom_bar(position = "fill", stat = "identity") +
      geom_text(size = 5, position = position_stack(vjust=0.5)) +
      geom_hline(aes(yintercept = tot_woman), linewidth=0.75) +
      scale_y_continuous(breaks = seq(0,1,0.2), labels = scales::percent) +
      scale_fill_manual(values = kandinsky2) +
      facet_wrap(~ subpop) +
      labs(x = paste("Within-organization wage ranks in", year_u(), "\n (",q_data()$n_org[1],"organizations with 50+ employees)"),
           y = "%", fill = "") +
      theme_minimal() +
      theme(legend.position = "bottom",
            strip.text.x = element_text(size = 20),
            axis.text = element_text(size = 15),
            axis.title = element_text(size = 15),
            legend.text = element_text(size = 15))
  }
  
  # Plot II: Wage deciles ------------------------------------------------------
  plotInput2 <- function(){
    ggplot(d_data(), aes(y=share, x=withind, fill=sex, label=round(pc, digits=2))) +
      geom_bar(position = "fill", stat = "identity") +
      geom_text(size = 5, position = position_stack(vjust=0.5)) +
      geom_hline(aes(yintercept = tot_woman), linewidth=0.75) +
      scale_x_continuous(breaks = seq(1,10,1)) +
      scale_y_continuous(breaks = seq(0,1,0.2), labels = scales::percent) +
      scale_fill_manual(values = kandinsky2) +
      facet_wrap(~ subpop) +
      labs(x = paste("Within-organization wage ranks in", year_u(), "\n (",d_data()$n_org[1],"organizations with 100+ employees)"),
           y = "%", fill = "") +
      theme_minimal() +
      theme(legend.position = "bottom",
            strip.text.x = element_text(size = 20),
            axis.text = element_text(size = 15),
            axis.title = element_text(size = 15),
            legend.text = element_text(size = 15))
    }
  
  # Print plots I (Wage quintiles) and II (Wage deciles)------------------------
  output$quintileplot <- renderPlot({print(plotInput())})
  output$decileplot <- renderPlot({print(plotInput2())})
  
  # Text: Notes (Wage quintiles) -----------------------------------------------
  output$notes <- renderText({ 
    paste('<strong>Notes:</strong> This figure visualizes sex segregation of wage earners across five wage ranks within Dutch organizations. The underlying population are all wage earners (excluding interns, WSW-ers, and DGAs) in Dutch organizations with at least 50 employees during the month of September. 
          Calculations are based on administrative linked employer-employee register data <a target="_blank" href="https://www.cbs.nl/nl-nl/onze-diensten/maatwerk-en-microdata/microdata-zelf-onderzoek-doen/microdatabestanden/spolisbus-banen-en-lonen-volgens-polisadministratie">(SPOLIS)</a> covering the entire underlying population. 
          Wage ranks are assigned to employees using the organization-specific distribution of hourly wages in September of a given year. 
          The first wage rank comprises the bottom 20% of wage earners, whereas the fifth wage rank comprises the top 20% of wage earners in each organization. 
          The overall share of men and women per wage rank can be calculated in two ways: (1) at the individual level (with larger organizations contributing more strongly to the total) or (2) normalized by organization size (all organizations contribute equally to the total).
          Calculations can be further refined along the dimensions of specific organizational characteristics. The reference line depicts the overall share of women across all wage ranks in the selected organizations.
          A coding break in the CBS sector classfication between 2016 and 2017 affects of the sector and ownership categories.')
  })
  
  # Text: Notes (Wage deciles) --------------------------------------------------
  output$notes2 <- renderText({ 
    paste('<strong>Notes:</strong> This figure visualizes sex segregation of wage earners across ten wage ranks within Dutch organizations. The underlying population are all wage earners (excluding interns, WSW-ers, and DGAs) in Dutch organizations with at least 100 employees during the month of September. 
          Calculations are based on administrative linked employer-employee register data <a target="_blank" href="https://www.cbs.nl/nl-nl/onze-diensten/maatwerk-en-microdata/microdata-zelf-onderzoek-doen/microdatabestanden/spolisbus-banen-en-lonen-volgens-polisadministratie">(SPOLIS)</a> covering the entire underlying population.
          Wage ranks are assigned to employees using the organization-specific distribution of hourly wages in September of a given year.
          The first wage rank comprises the bottom 10% of wage earners, whereas the tenth wage rank comprises the top 10% of wage earners in each organization. 
          The overall share of men and women per wage rank can be calculated in two ways: (1) at the individual level (with larger organizations contributing more strongly to the total) or (2) normalized by organization size (all organizations contribute equally to the total).
          Calculations can be further refined along the dimensions of specific organizational characteristics. The reference line depicts the overall share of women across all wage ranks in the selected organizations.
          A coding break in the CBS sector classfication between 2016 and 2017 affects of the sector and ownership categories.')
  })
  
  # Text: Colophon I -----------------------------------------------------------
  output$colophon <- renderText({ 
    paste('<strong>Colophon:</strong> This dashboard was created by <a target="_blank" href="https://christophjanietz.github.io">Christoph Janietz</a> with <code>R</code>, <code>RStudio</code> and <code>Shiny</code>. 
        This dashboard uses non-public microdata from Statistics Netherlands (CBS). Under certain conditions, these microdata are accessible for statistical and scientific research. For further information: <a target="_blank" href = "mailto:microdata@cbs.nl">microdata@cbs.nl</a>.
        Data is prepared and analyzed using <code>NIDIO</code> - an open code infrastructure assisting with the use of Dutch administrative register data <a target="_blank" href="https://osf.io/9b2xh/">(https://osf.io/9b2xh/)</a>.
        Contact me <a target="_blank" href = "mailto:c.janietz@rug.nl?subject = Feedback&body = Message">here</a> for questions or suggestions. Last update: January 2025.')
  })
  
  # Text: Colophon II ----------------------------------------------------------
  output$colophon2 <- renderText({ 
    paste('<strong>Colophon:</strong> This dashboard was created by <a target="_blank" href="https://christophjanietz.github.io">Christoph Janietz</a> with <code>R</code>, <code>RStudio</code> and <code>Shiny</code>. 
        This dashboard uses non-public microdata from Statistics Netherlands (CBS). Under certain conditions, these microdata are accessible for statistical and scientific research. For further information: <a target="_blank" href = "mailto:microdata@cbs.nl">microdata@cbs.nl</a>.
        Data is prepared and analyzed using <code>NIDIO</code> - an open code infrastructure assisting with the use of Dutch administrative register data <a target="_blank" href="https://osf.io/9b2xh/">(https://osf.io/9b2xh/)</a>.
        Contact me <a target="_blank" href = "mailto:c.janietz@rug.nl?subject = Feedback&body = Message">here</a> for questions or suggestions. Last update: January 2025.')
  })
  
  # Download handlers ----------------------------------------------------------
  output$save <- downloadHandler(
    file = "wagequintile_plot.pdf", 
    content = function(file) {
      ggsave(file,plot=plotInput(), width = 18, height = 12, units = "in")
    }) 
  
  output$save2 <- downloadHandler(
    file = "wagedecile_plot.pdf" , 
    content = function(file) {
      ggsave(file,plot=plotInput2(), width = 18, height = 12, units = "in")
    })    

} 

# Running the app ---------------------------------------------------------------
enableBookmarking(store = "url")
shinyApp(ui, server)
