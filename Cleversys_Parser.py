import numpy as np
import pandas as pd
import io as io
import re
import math
import seaborn as sns
import os


def parse(file):
    '''parse a file and return a dataframe and the animal ID'''
    with open(file) as f:

        #find the format string
        found = False
        frame_rate = None
        skip = 1
        while not found:
            skip +=1

            line = f.readline()

            if 'Frame Rate' in line:
                frame_rate = float(line.split(':')[1])
            #format line begins with 'Format:'
            if 'Format:' in line:
                found = True

                #raw column names. we'll get back to these, and rename them to make them more informative
                #also need to cleanup some of the cleversys output, because of course
                col_names_r = line.strip().replace('Motion\tOrientation(-pi/2 to pi/2)', 'Motion Orientation(-pi/2 to pi.2)\tUnknown').split('\t')
                col_names_r[0] = 'FrameNum'

            #find which side the partner is on. Animal 2 is always on the left
            if 'animal id' in line.lower():
                newline = f.readline()
                animal_ID = newline.split("\t")[line.lower().split('\t').index('animal id')]
                partner_pos = newline.split("\t")[line.lower().split('\t').index('side of partner')]
                treatment_group = newline.split("\t")[line.lower().split('\t').index('treatment')]
                raw_date = newline.split("\t")[line.lower().split('\t').index('last modified date')]

                #replace '/' with '_', then split date from the time and use that
                date = raw_date.replace('/','_').split(' ')[0]

                #figure out who is where
                if partner_pos.lower() == 'l' or partner_pos.lower() == 'left':
                    'Partner on left, animal_2 = partner'
                    animal_2 = 'partner'
                    animal_3 = 'novel'
                else:
                    'Partner on right, animal_3 = partner'
                    animal_2 = 'novel'
                    animal_3 = 'partner'

            #get the event rule number corresponding to huddling with partner or novel
            #the line looks like:
            # EventRule17: Social Contact [ 1 with 2 ] in Area left while Joint Motion < 0.040
            # so splitting on ':' and taking the first element will give the eventrule name
            #corrseponding to the metric

            #also grab the event rule name for some other key metrics,
            #like vole location, and vole within 100 mm

            rules = {}
            event_rule_numbers{}

            if 'Social Contact [ 1 with 2 ] in Area left'.lower() in line.lower():
                huddle_left = line.split(':')[0]

            if 'Social Contact [ 1 with 3 ] in Area right '.lower() in line.lower():
                huddle_right = line.split(':')[0]

            if 'Distance between [ 1 and 2 ] Less Than 100.00 mm'.lower() in line.lower():
                proximity_left = line.split(':')[0]

            if 'Distance between [ 1 and 3 ] Less Than 100.00 mm'.lower() in line.lower():
                proximity_right = line.split(':')[0]

            if 'Area:Vole 1 Stay/Hide In left'.lower() in line.lower():
                left_chamber = line.split(":")[0]

            if 'Area:Vole 1 Stay/Hide In right'.lower() in line.lower():
                right_chamber = line.split(":")[0]

            if 'Area:Vole 1 Stay/Hide In center'.lower() in line.lower():
                center_chamber = line.split(":")[0]

    #READ IN WITH PANDAS
    df = pd.read_table(file, skiprows = skip, header = None)

    #get rid of weird empty columns
    df.dropna(how = 'all', axis =  'columns', inplace = True)

    #rename columns with informative names, like "CenterX(mm)_partner". start
    #with an empty array that we will add col names to
    new_col = []

    #when we iterate over the column names we're essentially going "left to right",
    #so test animal --> animal_2 --> animal_3. We've already assigned the identity
    # (novel or partner) to animal_2 and animal_3, so we can use those variables
    #when redefining our column names
    for n in col_names_r:

        #if the column not yet in the col name list, add it.
        #first pass is for the test animal
        if not n in new_col:
            new_col.append(n)

        #if the col name plus animal_2 is there, add name plus animal_3
        elif n+'_'+animal_2 in new_col:
            new_col.append(n+'_'+animal_3)

        #otherwise, we're currently iterating over animal_2's columns.
        else:
            new_col.append(n+'_'+animal_2)

    #re-assign column names to the new column names.
    df.columns = new_col



    #we will replace uncertain rows with np.nan, but leave the frame number information.
    #these list comprehensions assemble lists of columns specific to test, novel,
    #and partner animals to set to np.nan, while leaving event rules alone.
    #We will leave the event rules UNCHANGED so that if cleversys thinks the animals are huddling
    #that will still be captured.
    take_me = [col for col in df.columns if 'Frame' not in col if 'Event' not in col if 'partner' not in col if 'novel' not in col]
    take_me_n =[col for col in df.columns if 'novel' in col]
    take_me_p = [col for col in df.columns if 'partner' in col]

    #use np.nan to remove data from times when animal pos is uncertain.
    #Cleversys sets CenterX(mm) and CenterY(mm) to -1 in these cases. We can
    #look at each animal seperately, so even if one animal is uncertain, the
    # others are available.
    df.loc[df['CenterX(mm)'] == -1, take_me] = np.nan
    df.loc[df['CenterX(mm)_novel'] == -1, take_me_n] = np.nan
    df.loc[df['CenterX(mm)_partner'] == -1, take_me_p] = np.nan


    #the following renames key Event Rule columns. Note that this must occur after
    #the above removal of bad values, or else columns without "Event" will also
    #be overriden.

    if partner_pos.lower() == 'l' or partner_pos.lower() == 'left':
        df.rename(columns={huddle_left:'huddle_partner',
        huddle_right:'huddle_novel', proximity_left:'partner_dist_less_10cm',
        proximity_right:'novel_dist_less_10cm',left_chamber:'chamber_partner',
        right_chamber:'chamber_novel',center_chamber:'chamber_center'}, inplace = True)

    else:
        df.rename(columns={huddle_right:'huddle_partner',
        huddle_left:'huddle_novel', proximity_right:'partner_dist_less_10cm',
        proximity_left:'novel_dist_less_10cm', right_chamber:'chamber_partner',
        left_chamber:'chamber_novel',center_chamber:'chamber_center'}, inplace = True)

    #reset frames so they start at 1
    df['FrameNum'] = df['FrameNum'] - df['FrameNum'].min() + 1

    #calculate time from frame num ( frame * 1 / (frame / sec)  --> sec )
    df['Time'] = df.FrameNum/frame_rate

    #add column of treatment group (IE Naive, Drug, etc)
    df['Treatment Group'] = treatment_group

    #reset the useless AnimalID column (cleversys sets it always to 1) to the number for the test vole
    df['[AnimalID]'] = animal_ID


    # np.linalg.norm can be used to calculate the distance between points
    # https://stackoverflow.com/questions/1401712/how-can-the-euclidean-distance-be-calculated-with-numpy/21986532
    # basically just a really fast way to take advantage of np to do:

    # sqrt((xt - xo)^2 + (yt - yo)^2)

    # where t is test and o is other animal

    df['distance_to_partner'] = np.linalg.norm((df['CenterY(mm)'] - df['CenterY(mm)_partner'],
                                df['CenterX(mm)'] - df['CenterX(mm)_partner']), axis = 0)

    df['distance_to_novel'] = np.linalg.norm((df['CenterY(mm)'] - df['CenterY(mm)_novel'],
                                df['CenterX(mm)'] - df['CenterX(mm)_novel']), axis = 0)

    # calculate distance traveled since last frame. First frame distance is
    #set to zero

    #make two offset arrays so we can simply subtract the finishX array
    #from the startX array, rather than going elementwise
    startX = df['CenterX(mm)'][:-1].values
    finishX = df['CenterX(mm)'][1:].values

    startY = df['CenterY(mm)'][:-1].values
    finishY = df['CenterY(mm)'][1:].values

    #use same strategy as distance_to_partner to calculate euclidean distance
    dist_traveled = np.linalg.norm((startX-finishX, startY-finishY), axis = 0)
    #add on a zero to the start of the array for frame 1
    dist_traveled = np.append(np.asarray([0]), dist_traveled)

    startX_partner = df['CenterX(mm)_partner'][:-1].values
    finishX_partner = df['CenterX(mm)_partner'][1:].values

    startY_partner = df['CenterY(mm)_partner'][:-1].values
    finishY_partner = df['CenterY(mm)_partner'][1:].values

    #use same strategy as distance_to_partner to calculate euclidean distance
    dist_traveled_partner = np.linalg.norm((startX_partner-finishX_partner, startY-finishY_partner), axis = 0)
    #add on a zero to the start of the array for frame 1
    dist_traveled_partner = np.append(np.asarray([0]), dist_traveled_partner)

    startX_novel = df['CenterX(mm)_novel'][:-1].values
    finishX_novel= df['CenterX(mm)_novel'][1:].values

    startY_novel = df['CenterY(mm)_novel'][:-1].values
    finishY_novel = df['CenterY(mm)_novel'][1:].values

    #use same strategy as distance_to_partner to calculate euclidean distance
    dist_traveled_novel = np.linalg.norm((startX_novel-finishX_novel, startY_novel-finishY_novel), axis = 0)
    #add on a zero to the start of the array for frame 1
    dist_traveled_novel = np.append(np.asarray([0]), dist_traveled_novel)

    df['distance_traveled'] = dist_traveled
    df['distance_traveled_partner'] = dist_traveled_partner
    df['distance_traveled_novel'] = dist_traveled_novel

    return df, animal_ID, frame_rate, date

def assemble_names(directory):
    '''return a list of paths to files to parse'''
    os.chdir(directory)

    #create an empty 2d list
    out_names = []

    #this will assemble a list of ALL filenames for images, sorted by timestamp of acquisition


    for root, dirs, files in os.walk(directory):
        out = [os.path.join(root, f) for f in sorted(files) if
            f.endswith('TCR.TXT') if not f.startswith('.')]
        out_names += out
    return out_names

def parse_and_convert_csv(file, out_file):
    '''parse a file aaaannnnndd output a csv file'''
    df, ani = parse(file)
    df.to_csv(out_file)
    return df, ani
