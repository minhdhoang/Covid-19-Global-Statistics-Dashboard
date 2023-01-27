/*------------------------------------
Retrieve all data from Covid-19 tables
------------------------------------*/
select *
from msdb..CovidDeaths
-- from msdb..CovidVaccinations
order by 3, 4


/*---------------------------------------
Total Deaths on Total Cases Accumulation
 <likelihood of dying if contract Covid>
---------------------------------------*/
select location, date, total_deaths, total_cases, (total_deaths*1.0/total_cases*1.0)*100 AS DeathPercentage, population
from msdb..CovidDeaths
-- where location LIKE 'United King%' -- specify location
order by 1, 2


/*----------------------------------
    Total Cases vs Population
<percentage of population got Covid>
-----------------------------------*/
select location, date, total_cases, population, (total_cases*1.0/population)*100 AS InfectionRate
from msdb..CovidDeaths
-- where location LIKE 'United King%'
order by 1, 2


/*------------------------------------------------------------
 Countries rank highest infection rate compared to population
-------------------------------------------------------------*/
select location, population, max(total_cases) AS TotalInfectionCount, max((total_cases*1.0/population)*100) AS InfectionRate
from msdb..CovidDeaths
where continent is not null
group by location, population
order by 4 desc


/*-------------------------------------------------
 Countries with highest death count per population
--------------------------------------------------*/
select location, population, max(total_deaths) AS TotalDeathCount, max((total_deaths*1.0/population)*100) AS DeathPercentage
from msdb..CovidDeaths
where continent is not null
group by location, population
order by 4 desc


/*----------------------------------------------------
Death percentages and total death counts per continent
-----------------------------------------------------*/
select continent, max(total_deaths) AS TotalDeathCount, max((total_deaths*1.0/population)*100) AS DeathPercentage
from msdb..CovidDeaths
where continent is not null
group by continent
order by 2 DESC


/*--------------------
    Global Data
<death rate per case>
---------------------*/
select 
    -- date,
    sum(new_cases) as calculated_total_cases,
    sum(new_deaths) as calculated_total_deaths,
    (sum(new_deaths)*1.0/sum(new_cases))*100 as death_rate_per_case
from msdb..CovidDeaths
where continent is not null
-- group by date
order by 1


/*---------------------------------
 Accumulated vaccinations over time
----------------------------------*/
select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
    sum(cv.new_vaccinations) 
    over (partition by cd.location order by cd.date) as AccumulatedVaccinations
from msdb..CovidDeaths cd
join msdb..CovidVaccinations cv 
    on cd.date  = cv.date
    and cd.location = cv.location
where cd.continent is not null
order by 2, 3


-- Finding rolling vaccinations against population over time sort by location

/*----------------------------
 CTE (Common Table Expression)
-----------------------------*/
with RollingVaccines (Continent, Location, Date, Population, New_Vaccinations, AccumulatedVaccinations)
as
(
    select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
        sum(cv.new_vaccinations) 
        over (partition by cd.location order by cd.date) as AccumulatedVaccinations
    from msdb..CovidDeaths cd
    join msdb..CovidVaccinations cv 
        on cd.date  = cv.date
        and cd.location = cv.location
    where cd.continent is not null
)
select *, (AccumulatedVaccinations*1.0/Population)*100 as AccumulatedVaccinationsPercentage
from RollingVaccines
order by 2, 3


/*--------------------
Use a temporary table
--------------------*/
drop table if exists RollingVaccines
create table RollingVaccines
(
    Continent nvarchar(255) null,
    Location nvarchar(255) not null, 
    Date date not null,
    Population int not null,
    New_Vaccinations int null,
    AccumulatedVaccinations bigint null
)

insert into RollingVaccines(Continent, Location, Date, Population, New_Vaccinations, AccumulatedVaccinations)
select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
    sum(cv.new_vaccinations) 
    over (partition by cd.location order by cd.date) as AccumulatedVaccinations
from msdb..CovidDeaths cd
join msdb..CovidVaccinations cv 
    on cd.date  = cv.date
    and cd.location = cv.location
where cd.continent is not null

select *, (AccumulatedVaccinations*1.0/Population)*100 as AccumulatedVaccinationsPercentage
from RollingVaccines
order by 2, 3


/*-------
 Use VIEW
--------*/
-- drop view if exists RollingVaccinesView -- for dropping views
create view RollingVaccinesView 
as
select cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
    sum(cv.new_vaccinations) 
    over (partition by cd.location order by cd.date) as AccumulatedVaccinations
from msdb..CovidDeaths cd
join msdb..CovidVaccinations cv 
    on cd.date  = cv.date
    and cd.location = cv.location
where cd.continent is not null

select *, (AccumulatedVaccinations*1.0/population)*100 as AccumulatedVaccinationsPercentage
from RollingVaccinesView
order by 2, 3


/*---------------------------------------------------------------------------------------
Rate of infection and rate of people with fully vaccinations against continent population
----------------------------------------------------------------------------------------*/
with populationpercontinenttable (continent, location, population, PopulationbyContinent) as
(
    select continent, location, population, sum(max(population)) over(partition by continent)
    from msdb..CovidDeaths
    group by continent, location, population
)

select cd.continent, cd.location,
    (max(total_cases)) as TotalInfectionCount, 
    (max(people_fully_vaccinated)) as TotalFullyVaccinatedPeople,
    PopulationbyContinent,
    (max(total_cases)*1.0/PopulationbyContinent)*100 as InfectionRateinContinent, 
    (max(people_fully_vaccinated)*1.0/PopulationbyContinent)*100 as TotalFullyVaccinatedRateinContinent
from msdb..CovidDeaths cd
join msdb..CovidVaccinations cv
    on cd.continent = cv.continent
    and cd.location = cv.location
join populationpercontinenttable pc
    on cd.continent = pc.continent
    and cd.location = pc.location
where cd.continent is not NULL
group by cd.continent, cd.location, pc.PopulationbyContinent
order by 1, 2