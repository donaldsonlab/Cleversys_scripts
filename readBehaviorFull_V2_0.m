%Ryan Cameron
%Date Created: 3/26/2018
%Date Modified: 2/6/2019
%--------------------------------------------------------------------------
%This script reads the behavior data into two different matlab matrices.
%The first one is the frame number and the calibration data for it
%(position and such). The second is the frame number and event marker for
%that specific event. This allows us to sync the data with the neuron frame
%by frame and compare them.
%--------------------------------------------------------------------------

clear all; close all; clc; %Housekeeping
working=pwd; %save the working file path

tic
%This initializes a few variables
behavCell={};
multAnimal=1;
animalCount=1;
name='test'; %Simply a placeholder string for the variable. Gets changed.

%This call the function that outputs all of the user inputs
[filename, path, iteration, useNum, runAll, timeBinLength]=getInputs(animalCount);
if useNum == 1
    fprintf('------Select The Folder With ALL Animal Data------\n');
    delPath = uigetdir();
end

%Get Number of files
obj=dir('**/*.txt');
numFiles=length(obj);

%This loop goes through each different animal(text file) that is in the
%folder with all of the test files
while multAnimal<=numFiles
%This if/then test simply assigns the name of the text file that will be
%loaded.

    name=obj(multAnimal).name;
    filename=strcat(path,name);

cd(working)
%% Read in the text file to matrices in MatLab
%This overarching if/then statement just test to see if the user wants to
%break the data into separate time bins or not.
if timeBinLength~=0
    %This test is for whether the user is loading in previous data from a
    %separate run of the program.
    if useNum~=1 %No previous data
        %Calls the function to read in the text file data
        [fullCal,fullEvent,count,timeBins,partnerChamber,contactIndex,animalNum,dataFolder,group]=readData(filename,timeBinLength,iteration,path);
        group=char(group);
        %This function breaks apart the data into the separate time bins
        [fullCal,fullEvent]=breakData(fullCal,fullEvent,timeBins,count);               
    else %This is is there is previous data to load 
        %Calls the function to load in the previous data
        [fullCal,fullEvent,count,timeBins,partnerChamber,contactIndex,animalNum,dataFolder,group]=loadPrevious(delPath,path,timeBinLength,filename,iteration);
        fprintf(sprintf('-----Data Loaded for Animal %d-----\n',animalNum));
        group=char(group);
        cd(working) %Change the working directory back to the original folder
        [fullCal,fullEvent]=breakData(fullCal,fullEvent,timeBins,count); %Separate data into the time bins
    end

    %This loops through each time bin that the user has specified
    imFolder=sprintf('\\Analysis%d_%d\\Plots\\',iteration,timeBinLength/29.97);
    if multAnimal==1
        mkdir(strcat(path,imFolder));
    end
    for k=1:timeBins
        space=count(k+1)-count(k); %Finds difference in the frames for this time bin
        binTime{k}=space/29.97; %Actual time of the bin in seconds
        
        %This calls the function to run analysis on the data
        [pTime,nTime]=analyzeFile(k+1,fullCal,fullEvent,path,imFolder,partnerChamber,animalNum);
        partnerT(k)=pTime/29.97; %time in partner chamber for this bin
        novelT(k)=nTime/29.97; %time in novel chamber for this bin
        
        %This calls the function that finds the distance and huddle data 
        [aveDistP,aveDistN,pHuddleTime,nHuddleTime,fullCal,fullEvent,testDist]=contactTime(fullCal,fullEvent,partnerChamber,contactIndex);
        %Find where there is NaN and replace with 0
        index=find(isnan(aveDistP));
        aveDistP(index)=0;
        index=find(isnan(aveDistN));
        aveDistN(index)=0;
        
        BinNames{k}=sprintf('%d',k); %This variable is the string arry of bin numbers for the excel file output
        groupNames{k}=group;
        
        %This check is to see if the user wants to manually run through
        %each time bin
        if runAll==0
            check=input('Continue? (Y/N) : ','s');
            check=char(check);
            check=upper(check); %Changes input to upper case
            if check=='N'
                break %breaks out of the loop if the user wants to stop after this bin
            end
        end
    end
    
    %THIS IS THE CONTACT TIME ANALYSIS FUNCTION CALL, MAYBE PUT IN LOOP?---
    

elseif timeBinLength==0 %If the user wants to run the whole file (no time bins)
    %Whether the user is loading previous data or not
    if useNum~=1 
        [fullCal,fullEvent,count,~,partnerChamber,contactIndex,animalNum,dataFolder,group]=readData(filename,timeBinLength,iteration,path);
        group=char(group);
        timeBins=1;
        [fullCal,fullEvent]=breakData(fullCal,fullEvent,timeBins,count);
    else
        [fullCal,fullEvent,count,~,partnerChamber,contactIndex,animalNum,dataFolder,group]=loadPrevious(delPath,path,timeBinLength,filename,iteration);
        fprintf(sprintf('-----Data Loaded for Animal %d-----\n',animalNum));
        group=char(group);
        cd(working)
        timeBins=1;
        [fullCal,fullEvent]=breakData(fullCal,fullEvent,timeBins,count);
    end
    
    %This is same as previous if/then section but no loop because there is
    %only one time bin
    imFolder=sprintf('\\Analysis%d_%d\\Plots\\',iteration,timeBinLength/29.97);
    if multAnimal==1
        mkdir(strcat(path,imFolder));
    end
    for k=1
        space=count(k+1)-count(k);
        binTime{k}=space/29.97; %Actual time of the bin
        
        %This runs the analysis function
        [pTime,nTime]=analyzeFile(k,fullCal,fullEvent,path,imFolder,partnerChamber,animalNum);
        partnerT(k)=pTime/29.97;
        novelT(k)=nTime/29.97;
        
        %This calls the function that finds the distance and huddle data
        [aveDistP,aveDistN,pHuddleTime,nHuddleTime,fullCal,fullEvent,testDist]=contactTime(fullCal,fullEvent,partnerChamber,contactIndex);
        %Find where there is NaN and replace with 0
        index=find(isnan(aveDistP));
        aveDistP(index)=0;
        index=find(isnan(aveDistN));
        aveDistN(index)=0;
        
        BinNames{k}=sprintf('%d',k);
        groupNames{k}=group;
    end
end

%% Clean Up Things
%This plots the bar graph of partner and novel times for each time bin
plotBar(partnerT, novelT, timeBinLength, timeBins, path, imFolder,animalNum);
%This outputs the cell that will be used to write the excel file
data={partnerT,novelT,aveDistP,aveDistN,pHuddleTime,nHuddleTime,testDist};
[writeCell]=excelCell(data, binTime, BinNames, animalNum,groupNames);
    if ~isempty(behavCell) %If this is not the first time through the overall loop
        writeCell(1,:)=[]; %This deletes the first row of the cell because it is just the names again.
    end
    behavCell=[behavCell; writeCell]; %Concatenates this animals data with all the previous data
    
%Iterates through the animal number
multAnimal=multAnimal+1;
animalCount=animalCount+1;
end
%Find empty cells in data and replace them with zeros
newName=sprintf('Analysis%d_%d\\behaviorData',iteration,timeBinLength/29.97);
writeName=strcat(path,newName); %Assigns the name of the excel file that will be saved
xlswrite(writeName,behavCell); %writes and saves the excel file

%Resets the working folder to the original folder the script was in
cd(working)
toc

%% getInputs
%Ryan Cameron
%Created:  5/2/2018
%Modified: 5/18/2018
%--------------------------------------------------------------------------
%This is a function declaration that will get all of the user inputs and
%run all of the inital stuff.
%--------------------------------------------------------------------------
function [filename, path, iteration, useNum, runAll, timeBinLength]=getInputs(animalCount)
%% Get User Inputs
%Have the user choose a file to read
[file,path]=uigetfile('*'); %Opens file explorer for user to select the FIRST text file
filename=strcat(path,file); %Creates full file path
cd(path); %Sets the directory to the text file folder

%Find if/how many logs the user has run before
if animalCount==1 %If this is the first text file being run
    obj=dir('*Analysis*'); %This gets information for all directories in the folder staring with 'Analysis'
    iteration=length(obj);
    iteration=iteration+1; %Sets the number of this run
    cd(path)
else
    obj=dir('*Analysis*');
    iteration=length(obj);
    cd(path)
end

%See if the user wants to delete previous data
check=1;
while check==1
    del=input('Use Previous Data? (Y/N): ','s'); %Get users input
    del=char(del); %Make it a character variable
    del=upper(del); %Make it all uppercase
    if (del=='Y')
        useNum=1; %Sets the output variable
        check=0; %Breaks out of the loop
    elseif del=='N'
        useNum=0; %Sets the output variable
        check=0; %Breaks out of the loop
    elseif del~='N' %If the user did not enter y or n, aka messed up
        warning('Character not recognized, try again') %Runs the loop again
    end
end

%Prompt user for a length of time bin to analyze
timeBinLength=input('What is the length of time bin to analyze (seconds, 0=whole time): ');
timeBinLength=timeBinLength*29.97; %Converts to frames

%This runs gets the input for whether the user wants to run through all of
%the time bins at once, or iterate through them manually and pause the
%program after each one is finished.
check=1;
while check==1
    runAll=input('Do you want to run all of the time bins? (Y/N): ','s'); %Gets the input
    runAll=char(runAll);
    runAll=upper(runAll); %Makes it uppercase character
    if runAll=='Y'
        runAll=1; %Assigns output variable
        check=0; %Breaks the loop
    elseif runAll=='N'
        runAll=0;
        check=0;
    else
        fprintf('Character not valid, please try again') %Makes the user re-enter a value
    end
end

%Get Number of text files that will be interated through
obj=dir('**/*.txt');
numFiles=length(obj);
end

%% readData
%Ryan Cameron
%Created:  5/15/2018
%Modified: 6/1/2018
%--------------------------------------------------------------------------
%This funciton will take the text file and read all of the data into a
%two cells. The first will be the calibration/position data for each animal
%in the test, the second will be the event data for each animal (3) in the
%test. It will also output the frames. NOTE: This is all based off of a
%certain output format from cleversys for the text files. If they do not
%adhere to the specific format, this will have to be modified.
%--------------------------------------------------------------------------

function [fullCal,fullEvents,count,timeBins,partnerChamber,contactIndex,animalNumber,dataFolder,group]=readData(filename,timeBinLength,iteration,path)
nowDate=date; %This creates a variable that is the current date
fileID=fopen(filename); %Opens the text file in MatLab's subroutines
for i=1:9
    [~]=fgets(fileID); %This skips the first part of the data where it just gives info about the file.
end

%This gets the first and last frame numbers
line=fgets(fileID);
    start=strsplit(line,':'); %Splits the string at the ':' delimiter
    start=start{2};
    start=str2num(start);

line=fgets(fileID);
    last=strsplit(line,':');
    last=last{2};
    last=str2num(last);

frames=last-start; %This is the frame number of the test

%Pulls out animal # and  partner chamber info from the text file. 
count=1;
for i=12:19
    if i==19 %The 19th line should be where this info is
        line=fgets(fileID);
        cline=strsplit(line);
        animal=cline{3}; %The third one should always be the animal #
            animalNumber=str2num(animal);
        group = cline{4};
        cham = cline{5};
        cham = lower(cham);
        if cham(1) == 'l'
            partnerChamber = 1;
        elseif cham(1) == 'r'
            partnerChamber = 0;
        else
            error(sprintf('Check the chamber designation in your file. It should say:\n left   OR\n right\n Your designation line is:\n%s',line))
        end
    else
        [~] = fgets(fileID);
    end
    count=count+1;
end

%This skips the rest of the file until the event data begins, it didn't
%seem like there was any relevant info in this portion
count=1;
eventNum=0;
for i=20:500
    if count<=3
        [~]=fgets(fileID);
        count=count+1;
    elseif count>3
        line=fgets(fileID);
        if strfind(line,'EventRule')==1
            eventNum=eventNum+1;
            if ~isempty(strfind(line,'Social Contact [ 1 with 2 ] in Area left while'))
                contactIndex(1)=eventNum+1; %This is the vector that contains the indexes of the event matrix to use in the analysis
            elseif ~isempty(strfind(line, 'Social Contact [ 1 with 3 ] in Area right while'))
                contactIndex(2)=eventNum+1;
            end
            count=count+1;
        elseif ~isempty(strfind(line,'Animal ID 1'))
            break
        end    
    end
end

%Now we actually start reading in the data, This is where things are
%different
dataFolder=sprintf('\\Analysis%d_%d\\Data%d\\',iteration,timeBinLength/29.97,animalNumber);
mkdir(strcat(path,dataFolder));

animal=textscan(fileID,'%s %s %s %s %s %s %s %s %s %s %s %s %s',frames,'Delimiter',']'); %This is meant to be too many columns, now reduce
%This trims away the extraneous columns
while isempty(animal{1,end}{1})
    animal(:,end) = [];
end
%Now we go and find the data we want
for i = 1:3
    frameNum = animal{1,1};
    if i == 1
        calMat = animal{1,2}; %Cell array of combo of numbers and 'center'
    elseif i == 2
        calMat = animal{1,5};
    elseif i == 3
        calMat = animal{1,8};
    end
    cal = zeros(size(calMat,1),11);
    for j = 1:length(calMat)
        frame = strsplit(frameNum{j});
        frame = str2num(frame{1});
        line = strsplit(calMat{j});
        line = char(line(1:10));
        line = str2num(line)';
        cal(j,:) = [frame,line];
    end
    %Save Calibration data
    filePathC=sprintf('calMat%d_%s.mat',i,nowDate);
    fileNameC=strcat(path,dataFolder,filePathC);
    save(fileNameC,'cal');
    
    fullCal{i} = cal;
end
events = animal{1,10};
events = char(events);
events = str2num(events);
events = [cal(:,1),events];
fullEvents{1} = events;
filePathE=sprintf('events%d_%s.mat',1,nowDate);
fileNameE=strcat(path,dataFolder,filePathE);
save(fileNameE,'events');

fullEvents{2} = events;
filePathE=sprintf('events%d_%s.mat',2,nowDate);
fileNameE=strcat(path,dataFolder,filePathE);
save(fileNameE,'events');

fullEvents{3} = events;
filePathE=sprintf('events%d_%s.mat',3,nowDate);
fileNameE=strcat(path,dataFolder,filePathE);
save(fileNameE,'events');

%Test whether there are multiple time bins or not
if timeBinLength~=0
    count=[1:round(timeBinLength):frames]; %This variable is what frame each time bin starts on, with the final frame number at the end
    count(length(count)+1)=frames;
else
    count(1)=1;
    count(2)=frames;
end
timeBins=round(frames/timeBinLength); %This is the total number of time bins the user has.
fclose(fileID)
end

%% breakData
%Ryan Cameron
%Created:  5/15/2018
%Modified: 5/17/2018
%--------------------------------------------------------------------------
%This function breaks up the data into data that can be analyzed for each
%timebin. This will output a cell of the data for each animal(columns)and
%each time bin(rows).
%--------------------------------------------------------------------------

function [fullCal,fullEvent]=breakData(fullCal,fullEvent,timeBins,count)
count(1)=0; %This makes the first number of the variable 0 to make calulations easier
s=size(fullCal);
%This loop goes through the columns of the data cell(each animal in the
%test chamber), should be 3
for i=1:s(2) 
    calMat=fullCal{1,i}; %Takes the full calibration matrix for this animal
    eventMat=fullEvent{1,i}; %Takes full event matrix
    count(end)=size(calMat,1); %Makes sure the last entry is the final frame number
    for j=1:timeBins %This loops through and creates the matrix for the data in a specific time bin
        newCal{j}=calMat(count(j)+1:count(j+1),:);
        newEvent{j}=eventMat(count(j)+1:count(j+1),:);
    end
    newCal=newCal';
    newEvent=newEvent';
    fullCal(2:timeBins+1,i)=newCal; %Adds this time bin appropriate data to the full data cell
    fullEvent(2:timeBins+1,i)=newEvent;
    clear newCal newEvent %Housekeeping
end
end

%% loadPrevious
%Ryan Cameron
%Created:  5/2/2018
%Modified: 8/1/2018
%--------------------------------------------------------------------------
%This loads in previous data from the folder being worked in.
%--------------------------------------------------------------------------

function [fullCal,fullEvent,count,timeBins,partnerChamber,contactIndex,animalNumber,dataFolder,group]=loadPrevious(delPath,path,timeBinLength,filename,iteration)
%% Have to read the first part of the file to get some animal info
fileID=fopen(filename); %Opens the text file in MatLab's subroutines
for i=1:9
    [~]=fgets(fileID); %This skips the first part of the data where it just gives info about the file.
end

%This gets the first and last frame numbers
line=fgets(fileID);
    start=strsplit(line,':'); %Splits the string at the ':' delimiter
    start=start{2};
    start=str2num(start);

line=fgets(fileID);
    last=strsplit(line,':');
    last=last{2};
    last=str2num(last);

% frames=last-start; %This is the frame number of the test

%Pulls out animal # and  partner chamber info from the text file. 
count=1;
for i=12:19
    if i==19 %The 19th line should be where this info is
        line=fgets(fileID);
        cline=strsplit(line);
        animal=cline{3}; %The third one should always be the animal #
            animal=str2num(animal);
        check=1;
        count=4;
        while check==1 %Now we have to go through the rest and find if it says left or right
            cham=cline{count};
            cham=lower(cham);
            if length(cham)==4
                if cham(1)=='l'
                    check=2;
                    partnerChamber=1;
                else
                    count=count+1;
                end
            elseif length(cham)==5
                if cham(1)=='r'
                    check=2;
                    partnerChamber=0;
                else
                    count=count+1;
                end
            else
                count=count+1;
            end
        end
        animalNumber=animal;   
    else
        [~]=fgets(fileID);
    end
    count=count+1;
end

%Finds the name of the group that the animals are in
group=string(cline(4:end-2));
new=group(1);
for i=2:length(group)
    new=new+' ';
    new=new+group(i);
end
group=new;

%This skips the rest of the file until the event data begins, it didn't
%seem like there was any relevant info in this portion
count=1;
eventNum=0;
for i=20:500
    if count<=3
        [~]=fgets(fileID);
        count=count+1;
    elseif count>3
        line=fgets(fileID);
        if strfind(line,'EventRule')==1
            eventNum=eventNum+1;
            if ~isempty(strfind(line,'Social Contact [ 1 with 2 ] in Area left'))
                contactIndex(1)=eventNum+1; %This is the vector that contains the indexes of the event matrix to use in the analysis
            elseif ~isempty(strfind(line, 'Social Contact [ 1 with 3 ] in Area right'))
                contactIndex(2)=eventNum+1;
            end
            count=count+1;
        elseif ~isempty(strfind(line,'Animal ID 1'))
            break
        end    
    end
end
fclose(fileID);

%% Get the actual event data
%Now select the folder with the data for the specific animal
cd(delPath) %Change the directory to the folder with ALL of the animal data
dataDir = sprintf('Data%d',animalNumber);
cd(dataDir) %Go to the folder with the specific animal data
anObj = dir('**/*.mat'); %Get all .mat files in the folder
delFile = extractfield(anObj,'name'); %Get a cell of the file names

%Find the calibration and event data
ind=strfind(delFile,'cal'); %Finds which file are the calibration data
%This loop makes empty cells into zeros
for j=1:length(ind)
    if isempty(ind{j})
        ind{j}=0;
    end
end
ind=find([ind{:}]==1); %Finds which indexes are the calibration data and loops through those
for i=1:length(ind)
    fileName=delFile{ind(i)}; %Find the filename
    load(fileName); %Load in the .mat file
    fullCal{i}=cal; %Assign the matrix to fullCal
end

%Repeat process for the event matrices
ind=strfind(delFile,'event');
for j=1:length(ind)
    if isempty(ind{j})
        ind{j}=0;
    end
end

ind=find([ind{:}]==1);
for i=1:length(ind)
    fileName=delFile{ind(i)}; %Find the filename
    s = load(fileName);
    events = s.events;
    fullEvent{i} = events; %Assign the matrix to fullEvent
end

cd(path)
dataFolder=sprintf('\\Analysis%d_%d\\Data%d\\',iteration,timeBinLength/29.97,animalNumber);
mkdir(strcat(path,dataFolder));
%%
%Find the count and the timeBins, because we have to create these variables
%still for the main script to run
frames=size(events,1); %Gets the total frames
%This checks to see if the user wants separate time bins or not. This
%should be familiar
if timeBinLength~=0
    count=[1:round(timeBinLength):frames];
    count(length(count)+1)=frames;
else
    count(1)=1;
    count(2)=frames;
end
timeBins=round(frames/timeBinLength);
end

%% analyzeFile
%Ryan Cameron
%Created:  5/2/2018
%Modified: 6/1/2018
%--------------------------------------------------------------------------
%This is the main analysis function that will do all of the calculations
%and such so that the user can see whatever data they want. Add any extra
%variables to analyze here.
%--------------------------------------------------------------------------
function [pTime,nTime]=analyzeFile(k,fullCal,fullEvent,path,imFolder,partnerChamber,animalNum)
% Begin Analyzing the data
fig=figure(1); %Creates the figure but hides it from the user
fig.Visible = 'off';
clf
%This loops through
for id=1:size(fullCal,2)
    %Pull out the specific matrix from the cell
    calMat=fullCal{k,id};
    eventMat=fullEvent{k,id};

    timeStep=calMat(:,1)/29.97; %This changes the time from frames to seconds
    timeStep=timeStep-timeStep(1); %This normalizes the time so it starts at 0 seconds
    calMat=[calMat(:,1) timeStep calMat(:,2:end)]; %This adds the time to the data matrix in a separate column
    eventMat=[eventMat(:,1) timeStep eventMat(:,2:end)];

    %Exclude bad data
    index=find(calMat(:,3)==-1); %Assuming that a negative 1 is not possible so it is just cleversys freaking out
    calMat(index,:)=[];
    eventMat(index,:)=[];

    %Plot the animal position over time in 3D
    hold on;
    plot3(calMat(:,3),calMat(:,4),calMat(:,2));
        grid on;
        xlabel('x-position');
        ylabel('y-position');
        zlabel('Time (s)');
        title('Animal Position with Time')
        view([-19 43]); %Set the inital viewing angle of the graph
end
imName=sprintf('bin%d_%d.jpg',k-1,animalNum); %Creates the file name for the image
imPath=strcat(path, imFolder, imName);
saveas(fig,imPath); %Saves the figure as a .jpg image

%Find when the test animal was in the partner or novel chamber
%Go back to the first animal, that is always the test animal
calMat=fullCal{k,1};
eventMat=fullEvent{k,1};
%This checks to see which chamber the partner vole is in
if partnerChamber==0 %Right
    indexP=find(eventMat(:,3)==1); %Finds when the vole is in the partner chamber
    indexN=find(eventMat(:,2)==1); %Novel chamber. These are based off of the event rules
elseif partnerChamber==1 %Left
    indexP=find(eventMat(:,2)==1);
    indexN=find(eventMat(:,3)==1);
end
pTime=length(indexP); %Finds total time spent in each chamber
nTime=length(indexN);
end

%% contactTime.m
%Ryan Cameron
%Created:  5/21/2018
%Modified: 5/21/2018
%--------------------------------------------------------------------------
%This function will find the average distance for partner and novel as well
%as the huddle times for each different vole. It will intake the full data
%cells just lik the last function and output four variables. 1) dist for
%partner and 2) dist for novel, 3) huddle time for partner and 4) huddle
%for novel.
%--------------------------------------------------------------------------

function [aveDistP,aveDistN,pHuddleTime,nHuddleTime,fullCal,fullEvent,testDist]=contactTime(fullCal,fullEvent,partnerChamber,contactIndex)
%This loop will go through each of the time bins in the data
for i=2:size(fullEvent,1)
    index1=find(fullCal{i,1}(:,3)==-1); %Here we exclude bad data
    index2=find(fullCal{i,2}(:,3)==-1);
    index3=find(fullCal{i,3}(:,3)==-1);
    fullInd=union(index1,index2); %All of the indexes that are BAD
    fullInd=union(fullInd,index3);

    eventMat=fullEvent{i,1}; %Separated the specific matrix for the test animal
    calMat=fullCal{i,1};
    
    %This singles out the partner and novel chamber
    if partnerChamber==0 %partner is in right
        indP=find(eventMat(:,3));
        indN=find(eventMat(:,2));
        index1=find(calMat(:,3)~=-1); %Here we exclude bad data
        pMat=eventMat(intersect(indP,index1),:); %This shrinks the matrices into just when the vole is in the chamber
        nMat=eventMat(intersect(indN,index1),:);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        pFull = find(fullInd <= length(fullCal{i,3}));
        pFull = fullInd(pFull);
        nFull = find(fullInd <= length(fullCal{i,2}));
        nFull = fullInd(nFull);
        
        %Now find when there is social contact
        index=find(pMat(:,contactIndex(2))); %Contact with partner
        pHuddle=length(index);
        index=find(nMat(:,contactIndex(1))); %Contact with novel
        nHuddle=length(index);
        
        %This finds the average distance between the animals
        calMat(fullInd,:)=[]; %Removes bad data from calibration
        eventMat(fullInd,:)=[];
        indP=find(eventMat(:,3));
        indN=find(eventMat(:,2));
        pCalData=fullCal{i,3}; %Finds partner calibration matrix
            pCalData(pFull,:)=[]; %fullInd
        nCalData=fullCal{i,2}; %Novel calibration matrix
            nCalData(nFull,:)=[]; %fullInd
        xyVecP=[calMat(:,2)-pCalData(:,2), calMat(:,3)-pCalData(:,3)];
        pDist=(xyVecP(:,1).^2+xyVecP(:,2).^2).^(1/2); %Normalize the data for each frame
        xyVecN=[calMat(:,2)-nCalData(:,2), calMat(:,3)-nCalData(:,3)];
        nDist=(xyVecN(:,1).^2+xyVecN(:,2).^2).^(1/2); %Normalize the data for each frame
        pDist=pDist(indP);
        nDist=nDist(indN);

        pDist=mean(pDist);
        nDist=mean(nDist);
        
        %Find the total distance traveled by the test animal
        totDist = hypot(diff(calMat(:,2)), diff(calMat(:,3)));   % Distance Of Each Segment
        totDist = sum(totDist);                                  % Total Distance
        
    elseif partnerChamber==1 %partner in left
        indP=find(eventMat(:,2));
        indN=find(eventMat(:,3));
        index1=find(calMat(:,3)~=-1); %Here we exclude bad data
        pMat=eventMat(intersect(indP,index1),:); %This shrinks the matrices into just when the vole is in the chamber
        nMat=eventMat(intersect(indN,index1),:);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        pFull = find(fullInd <= length(fullCal{i,2}));
        pFull = fullInd(pFull);
        nFull = find(fullInd <= length(fullCal{i,3}));
        nFull = fullInd(nFull);
        
        %Now find when there is social contact
        index=find(pMat(:,contactIndex(1))); %Contact with partner
        pHuddle=length(index);
        index=find(nMat(:,contactIndex(2))); %Contact with novel
        nHuddle=length(index);
        
        %This finds the average distance between the animals
        calMat(fullInd,:)=[]; %Removes bad data from calibration
        eventMat(fullInd,:)=[];
        indP=find(eventMat(:,2));
        indN=find(eventMat(:,3));
        pCalData=fullCal{i,2}; %Finds partner calibration matrix
            pCalData(pFull,:)=[];
        nCalData=fullCal{i,3}; %Novel calibration matrix
            nCalData(nFull,:)=[];
        xyVecP=[calMat(:,2)-pCalData(:,2), calMat(:,3)-pCalData(:,3)];
        pDist=(xyVecP(:,1).^2+xyVecP(:,2).^2).^(1/2); %Normalize the data for each frame
        xyVecN=[calMat(:,2)-nCalData(:,2), calMat(:,3)-nCalData(:,3)];
        nDist=(xyVecN(:,1).^2+xyVecN(:,2).^2).^(1/2); %Normalize the data for each frame
        pDist=pDist(indP);
        nDist=nDist(indN);

        pDist=mean(pDist);
        nDist=mean(nDist);
        
        %Find the total distance traveled by the test animal
        totDist = hypot(diff(calMat(:,2)), diff(calMat(:,3)));   % Distance Of Each Segment
        totDist = sum(totDist);                                  % Total Distance
    end
    %Allocates the pDist and nDist variables to a vector for all time bins
    aveDistP(i-1)=pDist;
    aveDistN(i-1)=nDist;
    testDist(i-1)=totDist;
    
    %Allocates pHuddle and nHuddle variables to vectors
    pHuddleTime(i-1)=pHuddle/29.97;
    nHuddleTime(i-1)=nHuddle/29.97;
end
end

%% plotBar
%Ryan Cameron
%Created:  5/2/2018
%Modified: 5/2/2018
%--------------------------------------------------------------------------
%This function outputs the bar graph of time spent with partner vs. novel
%voles.
%--------------------------------------------------------------------------
function []=plotBar(partnerT, novelT, timeBinLength, timeBins, path, imFolder,animalNum)
fig=figure(2); %Creates a figure in MatLab
clf
hold on
bars=[partnerT;novelT]; %This concatenates all of the time data
bars=bars';
if timeBinLength==0 %If we are plotting the whole data set
    bars(2,:)=[0 0];
    b=bar(bars); %Makes the bar graph
    xticks([1])
    xlim([.5 1.5]) %This is just setting the axis parameters
else
    b=bar(bars); %Makes the bar graph
    xticks([1:1:timeBins]) %Sets the axis parameters
end
b(1).FaceColor='b'; %This sets the color of each bar
b(2).FaceColor='m';
    legend('Partner','Novel')
    xlabel('Time Bin')
    ylabel('Time Spent With Animal (s)')
    title('Time Spent in Each Time Bin') %Labels the graph and creates the legend
imName=sprintf('timePlot%d.jpg',animalNum); %Makes the file name for the image
imPath=strcat(path, imFolder, imName);
saveas(fig,imPath); %This saves the figure as a .jpg image
end

%% excelCell
%Ryan Cameron
%Created:  5/2/2018
%Modified: 6/1/2018
%--------------------------------------------------------------------------
%This function writes the data to an excel file
%--------------------------------------------------------------------------
function [behavCell]=excelCell(data, binTime, BinNames, animalNum,groupNames)
%Create a Table of the time data for all of the test animals
for i=1:length(data)
    input(i,:)=data{i};
end
behavTab=array2table(input);
behavCell=table2cell(behavTab);
behavCell=[behavCell(1:2,:);binTime;behavCell(3:end,:)]; %Add the variable data to the bottom of the cell

animalNum=num2cell(zeros(1,width(behavTab))+animalNum);
animalNum=['Animal' animalNum];
BinNames=['Bin Number' BinNames]; %Create labels names in the cell
Groups=['Test Group' groupNames];
VariNames={'pTime';'nTime';'BinTime';'aveDistP';'aveDistN';'pHuddle';'nHuddle';'Total Distance Traveled (mm)'}; %Create variable names
behavCell=[VariNames behavCell]; %Concatenate horizontally
behavCell=[animalNum;BinNames;Groups;behavCell]'; %Concatenate vertically and tranpose
end