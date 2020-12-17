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
from tkinter import messagebox, filedialog, simpledialog
import tkinter as tk

def run_bin_analysis(start_dir = "/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1", 
                 save_dir = "/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output_binned",
                 suppress_csv = True,
                 bin_time = 7200):
    
    if not os.path.isdir("/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output_binned"):
        os.mkdir("/media/dprotter/Storage/Cleversys/CleverSys tracking txt files/Baseline_Cohort1_output_binned")
    #David Protter
    '''Parse all files in a folder. Run standard set of analysis and ouput basic plots.
    Convert all parsed files to CSV to make it easier to work with them in the future.'''
    computer_platform = platform.system()
    if computer_platform in ['Darwin', 'Linux']:
        initialdir = '/'
    else:
        initialdir = ''

    ###the following code was for using the computer's messagebox to set 
    '''messagebox.showinfo('yo dawg', 'where the files at?!?!')
    start_dir = filedialog.askdirectory(initialdir = initialdir)

    choose_save_dir = messagebox.askquestion(message = 'Choose File Output Location? Otherwise the script will choose for you, in the folder where the files are at', )
    if choose_save_dir == 'yes':
        save_dir = filedialog.askdirectory(initialdir = initialdir)
    else:
        save_dir = start_dir

    #create a tkinter window to ask how long of a timebin to use, convert to sec
    window = tk.Tk()
    bin_time = simpledialog.askfloat('timebins?',
                'timebin length in minutes? (0 = no timebins. )', parent = window) * 60

    window.destroy()'''

    #make a new savdir for plots only
    plot_out_path = os.path.join(save_dir, 'plots')
    try:
        os.mkdir(plot_out_path)
    except:
        traceback.print_exc()
        print('plot dir already exists')

    #make a new directory for csv files
    csv_out_path = os.path.join(save_dir, 'csv_files')
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
            full_df, ani, frame_rate, date, change_log = cp.parse(file)
        except Exception:
            print('oh no, a wild exception appears!')
            print(traceback.format_exc())
            print('here is the offending file. Better double check it: ')
            print(file)

            continue
        print(f'it took {time.time() - start_time} sec to parse')
        

        #the start and finish times of the first window. we will use These
        #to slice the full data frame
        max_time = full_df.Time.max()
        window_start_time = 0
        window_finish_time = window_start_time + bin_time
        bin_number = 1

        #keep going until the start time is outside of the dataframe (after the max time)
        #note that the case where the end of the window is outside of the DataFrame
        #is handled when slicing, as (full_df.Time < window_finish_time) will naturally
        #capture the end of the dataframe. this is in contrast to slicing an array
        #where we'd have to identify when we reached the end and sliced appropriately
        while window_start_time < max_time:
            df = full_df.loc[(full_df.Time > window_start_time) &
                            (full_df.Time < window_finish_time)]
            
            df, change_log = cp.correct_chamber_assignments(df)
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

            animal_num = ani.replace("['", '').replace("']", '')

            #output bin length in minutes to match user input
            actual_bin_length = (df.Time.max() - df.Time.min()) / 60

            #note reassigned rows
            reassigned_rows = len(df.loc[df['modified_due_to_uncertainty'] > 0])

            this_metrics = pd.DataFrame(data = {'animal':[animal_num],
                                                'num_reassigned_rows':[reassigned_rows],
                                                'reassigned_pct':[100*np.round(reassigned_rows / len(df), 3)],
                                                'treatment':[treatment_group],
                                                'bin number':bin_number,
                                                'bin length (min)': actual_bin_length,
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

            #set window for next iteration, iterate bin number
            window_start_time = window_finish_time
            window_finish_time = window_start_time + bin_time
            bin_number += 1
            pd.DataFrame(data = change_log[1:], columns=change_log[0]).to_csv(
                                        os.path.join(plot_out_path, f'change_log_{ani}_bin_{bin_number}_{date}.csv'))

        time_3d_fig = uf.make_3d_movement_plot(df)
        time_3d_fig.savefig(os.path.join(plot_out_path, f'{ani}_{date}_movement'))
        plt.close(time_3d_fig)
        
        time_2 = time.time()
        #save the DF as a CSV file for fast parsing later. Can easily open this CSV
        #in your favorite program/language for analysis.
        base_file_name = os.path.basename(file).split('.TXT')[0]+'_'+ani+'_'+'.csv'
        new_file_name = os.path.join(csv_out_path, base_file_name)

        full_df.to_csv(os.path.join(save_dir,new_file_name))
        print(f'it took {time.time() - time_2} sec to save to csv')

        for ani in output_metrics.animal.unique():
            sli = output_metrics.loc[output_metrics.animal == ani]
            fig = uf.binned_huddle_fig(sli, ani)
            fig.savefig(os.path.join(plot_out_path, f'{ani}_{date}_huddle'))
            plt.close(fig)
    output_metrics.to_csv(os.path.join(csv_out_path,'summary.csv'))

if __name__:
    run_bin_analysis()