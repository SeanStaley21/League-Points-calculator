# League-Points-calculator
This folder includes an excel file that helps with tracking of a gokarting league and a python program that aids in kart time sorting for the divisions
the excel file has a couple sheets: Roster, Leaderboards, Points calculator, Juniors, Division 1-3

  ## roster:
  allows adding drivers to divisons (MAX 13)
  names are first and last name
  adding their weights
  this sheet is the only way to change names as everything name-wise references this sheet for them

  ## Leaderboards:
  shows all the points per week per league
  has a total row at the end that includes the rule for dropping lowest scoring week
  this whole page is locked to prevent messing up any of the formulas

  ## Points Calculator:
  this is how points are added to the leaderboard
  you input the finish into the pink/purple column
  the points in the green column are then computed and added to leaderboard
  there is a template of what the point allocation is per finish in the top left of the sheet

  ## Juniors & Divisions 1-3:
  these sheets are used for kart picking
  the JUNIORS sheet is the only way to edit the DATE as the other sheets just refer to that cell
  the DIVISION 1 sheet is the only way to edit the kart times on DIVISIONs 2 & 3 as they just refer to those cells aswell.

# Python Program
*Created with help from copilot both microsoft and github*

  ## Pre requisites before running the program
  1) The program requires to get the user to save the excel file of the kart times from clubspeed
  2) you then go into excel to convert it to a .csv file
  3) save the file to your downloads folder

  ## Actual program
  you just run the .exe file that is in the dist folder (League-Points-calculator\Kart time program\dist)
  the program sorts the .csv data into groups of Pros, Intermediates, and Juniors
  it then organizes the fastest 'best lap' times towards the top and slowest to the bottom of the list
  prints all the data to the command line neatly using a python library called 'rich'
  then prompts the user to press 'enter' to exit
