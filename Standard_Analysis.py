import Cleversys_Parser as cp
import os
import platform
import pandas as pd
import Useful_Functions as uf
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import traceback
import time
import numpy as np
#David Protter
'''Parse all files in a folder. Run standard set of analysis and ouput basic plots.
Convert all parsed files to CSV to make it easier to work with them in the future.'''
computer_platform = platform.system()
if computer_platform in ['Darwin', 'Linux']:
    initialdir = '/'
else:
    initialdir = ''

from tkinter import messagebox, filedialog
'''messagebox.showinfo('yo dawg', 'where the files at?!?!')
start_dir = filedialog.askdirectory(initialdir = initialdir)
output_metrics
choose_save_dir = messagebox.askquestion(message = 'Choose File Output Location? If "no", output will be placed in same folder as the input files', )
if choose_save_dir == 'yes':
    save_dir = filedialog.askdirectory(initialdir = initialdir)
else:
    save_dir = start_dir'''


def run_analysis(start_dir = "/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1", 
                 save_dir = "/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output",
                 suppress_csv = True):
    
    if not os.path.isdir("/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output"):
        os.mkdir("/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output")
    #make a new savdir for plots only
    plot_out_path = os.path.join(save_dir, 'python_output')
    try:
        os.mkdir(plot_out_path)
    except:
        print('plot dir already exists')

    #make a new directory for csv files
    csv_out_path = os.path.join(save_dir, 'parsed_csv_files')
    try:
        os.mkdir(csv_out_path)
    except:
        print('csv dir already exists')

    #get file paths
    files = cp.assemble_names(start_dir)
    num_files = len(files)

    output_metrics = pd.DataFrame()

    for i, file in enumerate(files):
        start_time = time.time()
        print(f'working on file {i+1} of {num_files}')
        print(file)
        try:
            df, ani, frame_rate, date = cp.parse(file)
        except Exception:
            print('oh no, a wild exception appears!')
            print(traceback.format_exc())
            print('here is the offending file. Better double check it: ')
            print(file)

            continue
        
        print(f'it took {time.time() - start_time} sec to parse')
        
        time_change = time.time()
        df, change_log = cp.correct_chamber_assignments(df)
        print(f'took {time.time() - time_change} to fix errant chamber assignments')
        #huddle time novel,  partner, and total
        hn, hp, htot = uf.huddle_time(df, frame_rate)

        #get treatment_group
        treatment_group = df['Treatment Group'].unique()[0]

        #calculate time in partner, novel, and center chambers
        chamber_time_dict = uf.chamber_time(df, frame_rate)

        #normalized preference (--> pHuddle %)
        if htot >0:
            norm_pref = hp / (htot)
        else:
            norm_pref = np.nan

        #calculate average distance between test animal and other animals
        average_distance_novel = df['distance_to_novel'].mean()
        average_distance_partner = df['distance_to_partner'].mean()

        #calculate total locamotion
        total_distance_traveled = df['distance_traveled'].sum()

        #note reassigned rows
        reassigned_rows = len(df.loc[df['modified_due_to_uncertainty'] > 0])
        
        animal_num = ani.replace("['", '').replace("']", '')
        this_metrics = pd.DataFrame(data = {'animal':[animal_num],
                                            'num_reassigned_rows':[reassigned_rows],
                                            'reassigned_pct':[100*np.round(reassigned_rows / len(df), 3)],
                                            'treatment':[treatment_group],
                                            'bin number':0,
                                            'huddle time partner':[hp],
                                            'huddle time novel':[hn],
                                            'huddle time total':[htot],
                                            'percent pHuddle':[norm_pref],
                                            'chamber time partner':[chamber_time_dict['chamber_partner']],
                                            'chamber time novel':[chamber_time_dict['chamber_novel']],
                                            'chamber time center':[chamber_time_dict['chamber_center']],
                                            'average distance to novel':[average_distance_novel],
                                            'average_distance to partner':[average_distance_partner],
                                            'total distance traveled': [total_distance_traveled],
                                            })

        output_metrics = output_metrics.append(this_metrics)
        time_3d_fig = uf.make_3d_movement_plot(df)
        huddle_fig = uf.make_huddle_time_polt(hp, hn, animal_num)
        time_3d_fig.savefig(os.path.join(plot_out_path, f'{ani}_{date}_movement'))
        huddle_fig.savefig(os.path.join(plot_out_path, f'{ani}_{date}_huddle_time'))

        pd.DataFrame(data = change_log[1:], columns=change_log[0]).to_csv(
                                    os.path.join(plot_out_path, f'change_log_{ani}_{date}.csv'))
        
        #save the DF as a CSV file for fast parsing later. Can easily open this CSV
        #in your favorite program/language for analysis.
        base_file_name = os.path.basename(file).split('.TXT')[0]+'_'+ani+'_'+'.csv'
        new_file_name = os.path.join(csv_out_path, base_file_name)
        if not suppress_csv:
            df.to_csv(os.path.join(save_dir,new_file_name))

    #kinda assuming they're all from the same date here
    output_metrics.to_csv(os.path.join(plot_out_path, f'output_metrics_{date}.csv'))
    
if __name__:
    run_analysis()