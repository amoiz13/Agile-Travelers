# Agile-Travelers-
A multi-modal Swedish Public Transit Planner app.
# Swedish Public Transit Planner App

## Overview
This repository contains the codebase for our Swedish Public Transit Planner App, developed as part of "Course Software development and agile learning ". The primary goal is to produce a reliable application that allows the group members to practice Agile techniques over three sprints, providing real-world experience for our individual academic reports[cite: 2].

The application utilizes the Trafiklab ResRobot API to fetch real-world transport routes, timings, and operators[cite: 2]. Because open APIs do not provide live ticket prices or CO2 data, our team is implementing a custom CO2 calculator to estimate emissions per leg of the journey, alongside a trip cost estimator based on regional rules[cite: 2].

## Team Roles
* **Znana Prasanna Peddinti (Scrum Master / Product Owner):** Facilitates daily scrums, tracks team velocity, and manages the sprint burndown chart[cite: 2].
* **Federico Di Stefano (API Documentation Lead):** Writes OpenAPI/Swagger specifications and manages test collections[cite: 2].
* **Abdul Moiz Javaid (Frontend Developer):** Develops the mobile frontend, search interfaces, and UI result cards[cite: 2].
* **Lokeshraja Balaji (Backend Developer):** Builds the REST API and integrates the Trafiklab ResRobot endpoints[cite: 2].
* **Gabriele Passini (Algorithm & Data Developer):** Implements the custom math engines for travel cost and CO2 emissions[cite: 2].

## Sprint 1 MVP Features
* **Location Search:** Origin and destination input fields that fetch valid ResRobot station IDs[cite: 1].
* **Route Display:** Chronological breakdown of journey legs, including transport modes, transfer counts, and exact travel times[cite: 1].
