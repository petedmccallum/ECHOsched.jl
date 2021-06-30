# ECHOsched

A library for inferring Electricity, Cooling, Heating, and Occupancy schedules from real demand data.

### What is ECHOsched

This library contains a range of discrete routines to interpret features in energy demand data. In its raw form, household demand data lends itself only to basic aggregation and statistical description, although specialised routines can also be used to explore further insight form more complex statistical and machine learning methods. In contrast, from the perspective of exploiting household demand data for use in deterministic simulation models, it is always of benefit to decompose the signal(s) and interpret state-change events for different energy demands. ECHOsched offers a number of routines that can isolate certain demands, to support modelling for tools such as [EnergyPlus](https://energyplus.net/). 

One of the main features of ECHOshed is the method of aggregating large volumes of behavioural patterns into statistically representative records. This is achieved through **Control Event Matrices**.

### Model specification

1. To provide the basis for probabilistic temporal control functions and corresponding temporal diversity in physics-based, energy demand models;
2. To automate processes which utilise large quantities of smart meter data to interpret underlying behaviours, useful for Urban Building Energy Modelling;
3. To augment and complement both traditional Time Use Survey data and the evolving Machine Learning based methods for energy modelling, to provide a logic-based scheme that can be interpreted and enhanced with new methods;
4. To facilitate modelling following cultural adaptations to behaviour due to changes in energy practices and propagation of new technology (e.g. heat pumps, demand side response, batteries)
5. To provide robust and lightweight code modules and data structures which are inherently extensible and adaptable;
6. To ensure model(s) are replicable, accessible, versatile and portable

### Inferring events

Isolation routines are chosen based on:

1. the quantity being measured (with energy, power, temperature, etc. being treated as required)
2. the specific character of demand being processed (heating time series shapes also depend on technology, likewise for cooling);
3. the data sample rate.

For half-hourly gas energy data, for example, the most robust method is k-means clustering across discrete dwelling-day sample, with system states labelled as the figure below:

![ControlScheduleMatrix.png](http://39e38bfc8bfe017f9f2d17df1-16003.sites.k-hosting.co.uk/assets/images/SampleData3.png)



The procedure treats each specific day differently; each subsequent day establishes new cluster centres internally within the routine. Over the course of a week, patterns can emerge thorough the derived state conditions, highlighted in the figure below. 

![ControlScheduleMatrix.png](http://39e38bfc8bfe017f9f2d17df1-16003.sites.k-hosting.co.uk/assets/images/Week_sample.png)

The nature of these control state cycles can vary drastically form site to site, as this represents stochastic activity patterns. Bulk data can be categorised, in terms of control regimes, such as 'program-led' or 'ad-hoc control'.  This can be achieved across longitudinal data, over many seasons, and can be extended across thousands of dwellings to build a statistically representative description of system control over a large cohort of real sites. For each identified daily sequence (for 1000+ sites this can be in the region of 500k control schedules), the relationship between each on/off event can be used to generate state-change distributions with respect to time-of-day, in terms of control event matrices.

![ControlScheduleMatrix.png](http://39e38bfc8bfe017f9f2d17df1-16003.sites.k-hosting.co.uk/assets/images/Full_sample.png)


### Control Event Matrices

These records can be used to stochastically generate large volumes of heating control schedules for energy simulation. For a single dwelling-day, the matrices are used to identify an initial event at the start of the day, which generates a self-led path along distributions according to the previous result. This is very simple routine that can be repeated hundreds of thousands of times to create annual control instructions, across thousands of dwellings. 

Different matrices can be used to represent specific cohorts of dwellings/households, in terms of geography and urban context; the underlying data used to generate any matrices dictates what the results represent, which will be constrained by the availability of contextual data accompanying the measured time series. 

![ControlScheduleMatrix.png](http://39e38bfc8bfe017f9f2d17df1-16003.sites.k-hosting.co.uk/assets/images/ControlScheduleMatrix.png)