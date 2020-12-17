import numpy as np
from Cleversys_Parser import parse
import matplotlib.pyplot as plt
def huddle_time(df, frame_rate):
    '''return the huddle time for novel and partner. Uses frame rate to
    calculate from the number of frames where cleversys event rules for
    huddle_novel and huddle_partner are 1'''

    huddle_novel = len(df.loc[df['huddle_novel'] >0]) / frame_rate
    huddle_partner = len(df.loc[df['huddle_partner'] >0]) / frame_rate
    print(huddle_novel)
    print(huddle_partner)
    return huddle_novel, huddle_partner, huddle_novel+huddle_partner

def chamber_time(df, frame_rate):
    '''return the time spent in each chamber for novel and partner. Uses frame rate to
    calculate from the number of frames where cleversys event rules for
    huddle_novel and huddle_partner are 1'''

    chamber_novel = len(df.loc[df['chamber_novel'] >0]) / frame_rate
    chamber_partner = len(df.loc[df['chamber_partner'] >0]) / frame_rate
    chamber_center = len(df.loc[df['chamber_center'] >0]) / frame_rate

    return {'chamber_partner':chamber_partner, 'chamber_novel':chamber_novel, 'chamber_center':chamber_center}

def make_3d_movement_plot(df):
    '''make a 3d plot of animal movement over time'''

    zs = df['Time'].astype('float').interpolate()

    fig = plt.figure(figsize = (15,10))
    ax = fig.add_subplot(111, projection='3d')
    ax.plot(xs=df['CenterX(mm)'].astype('float').interpolate(),
            ys = df['CenterY(mm)'].astype('float').interpolate() ,
            zs = zs, alpha = 1,linewidth = 1, color = 'green')


    ax.plot(xs=df['CenterX(mm)_partner'].astype('float').interpolate(),
            ys = df['CenterY(mm)_partner'].astype('float').interpolate(),
            zs = zs, alpha = 0.5, linewidth = 0.5, color = (1,0,1))

    ax.plot(xs=df['CenterX(mm)_novel'].astype('float').interpolate(),
            ys = df['CenterY(mm)_novel'].astype('float').interpolate(),
            zs = zs , alpha = 0.5,linewidth = 0.5, color = (0,0,1))
    fig.legend(['test', 'partner', 'novel'])
    ax.set_title(df['[AnimalID]'].unique()[0])
    return fig

def make_huddle_time_polt(huddle_p, huddle_n, plot_title = '', same_color = False):
    '''make a plot of huddle time for partner vs novel'''
    if same_color:
        c1 = (0,0,1)
        c2 = (0,0,1)
    else:
        c1 = (1,0,1)
        c2 = (0,0,1)
    fig, ax = plt.subplots()
    ax.bar(x = 1, height = huddle_p, color = c1)
    ax.bar(x = 2, height = huddle_n, color = c2)
    ax.set_title(plot_title)
    ax.set_ylabel('Huddle Time (s)')
    ax.set_xticks((1,2))
    ax.set_xticklabels(['Parter', 'Novel'])

    return fig

def binned_huddle_fig(sli, ani):


    rounds = sorted(sli['bin number'])
    hp = []
    hn = []
    round_length = []
    for rr in rounds:
        hp.append(sli.loc[sli['bin number'] == rr, 'huddle time partner'][0])
        hn.append(sli.loc[sli['bin number'] == rr, 'huddle time novel'][0])
        round_length.append(sli.loc[sli['bin number'] == rr, 'bin length (min)'][0])
    hp_ar = np.asarray(hp)
    hn_ar = np.asarray(hn)

    total_hp = np.sum(hp_ar)
    total_hn = np.sum(hn_ar)

    fig, axs = plt.subplots(ncols = 2, constrained_layout = True)
    barwidth = 0.25
    buffer = 0.05


    #get x values for hp
    hpx = np.arange(len(rounds))

    #offset by barwidth
    hnx = [x+barwidth+buffer for x in hpx]

    axs[0].bar(hpx, hp_ar, color = (1,0,1), width = barwidth)
    axs[0].bar(hnx, hn_ar, color = (0,0,1), width = barwidth)
    axs[0].set_xticks(np.asarray(rounds)-1)
    axs[0].set_xticklabels([str(r) + "\n" + str(np.round(len,1)) for r, len in zip(rounds, round_length) ])
    axs[0].set_title('Binned Huddle Time')
    axs[0].set_xlabel('Bin\nbin time (min)')
    axs[0].set_ylabel('huddle time (s)')
    axs[1].bar(0,total_hp, color = (1,0,1), width = barwidth)
    axs[1].bar(0+barwidth+buffer, total_hn, color = (0,0,1), width = barwidth)
    axs[1].set_title('Total Huddle Time')
    axs[1].set_ylabel('huddle time (s)')
    axs[1].set_xticks([0,0.3])
    axs[1].set_xticklabels(['Partner','Novel'])

    fig.suptitle(ani, fontsize = 16)
    return fig
