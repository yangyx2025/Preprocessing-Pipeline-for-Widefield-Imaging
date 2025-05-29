%yyx20250505同步瞳孔(适用于只有一个相机，采集瞳孔）
clear;clc;close all
FunAddPath()
rootpath='K:\m0728\20240828_sleep_sti';
bv_path='K:\m0728\20240828_sleep_sti\video\bv_m0728-all-2025-05-03\videos';
bv_name='m0728DLC_resnet50_bv_m0728May3shuffle1_10000.csv';
p_th=0.9;%似然度低于0.9将被平滑
sm_win=20;%数据平滑长度
daq_sample_rate=1000;
%% 读取数据
bv=FunLoadDLCData(bv_path,bv_name);%读取行为数据
%读取neuron align
[savepath,neuron_align]=FunLoadNeuronalign(rootpath);
%% 数据预处理
FunCheckData(bv,neuron_align.syc_event);%检查掉帧
bv_sm=FunPreProcessData(bv,p_th,sm_win);%平滑数据，去掉nan值
pupil=FunGetPupilChara(bv_sm);%计算特征
%% 数据同步
pupil=FunSycTime(pupil,neuron_align.syc_event,daq_sample_rate);
%% 数据存储
neuron_align.bv.pupil=pupil;
save(fullfile(rootpath,'res','neuron_align03.mat'),'neuron_align','-v7.3');
%% function
function pupil=FunSycTime(pupil,syc_event,daq_sample_rate)
    %截取有效部分
    event_time=[syc_event.exp_event(1),syc_event.exp_event(end)];
    bv_logical=syc_event.bv_event>event_time(1)&syc_event.bv_event<event_time(2);
    exp_time=(syc_event.bv_event-event_time(1))./daq_sample_rate;
    pupil=pupil(bv_logical,:);
    pupil.time=exp_time(bv_logical);
end
function res=FunGetPupilChara(bv)
    %计算瞳孔中心点位置和半径
    px=[bv.p1.x,bv.p2.x,bv.p3.x,bv.p4.x];
    py=[bv.p1.y,bv.p2.y,bv.p3.y,bv.p4.y];
    px_avr=mean(px,2);
    py_avr=mean(py,2);
    for j=1:4
        buff=[px(:,j),py(:,j)]-[px_avr,py_avr];
        pr(:,j)=vecnorm(buff,2,2);%计算每一列范数，即欧几里得距离；表征瞳孔半径
    end
    pr_avr=mean(pr,2);

    res = struct( ...
        'px_avr', px_avr, ...
        'py_avr', py_avr, ...
        'pr_avr', pr_avr ...
    );
    res=struct2table(res);
end
function FunCheckData(bv,syc_event)
    %检查掉帧以及与event的关系
    bv_event=syc_event.bv_event;
    %检查与event的关系
    if bv_event(1)>syc_event.exp_event(1)||bv_event(end)<syc_event.exp_event(end)
        error('行为视频在event之内停止或者开始');
    end
    %检查掉帧
    chara_name=fieldnames(bv);
    chara_frame=size(bv.(chara_name{1}),1);
    event_num=numel(bv_event);
    fprintf('检查发现差%d帧，无问题可继续\n',abs(chara_frame-event_num));
    keyboard
end
function bv_sm=FunPreProcessData(bv,th,sm_win)
    %根据似然度去掉不稳定值，然后平滑
    bv_sm=struct();
    chara_names=fieldnames(bv);
    for i=1:numel(chara_names)
        chara=bv.(chara_names{i});
        bad_predict_logical=chara.p<th;
        bad_chara_predict_ratio=sum(bad_predict_logical)/height(chara);
        if bad_chara_predict_ratio<0.05
            fprintf('行为特征%d中检测到%.2f比例的预测值似然度低于阈值\n',i,bad_chara_predict_ratio);
        else
            disp('过多的低似然度拟合，请检查数据');
            keyboard
        end
        %将低于阈值的预测值设置为nan值
        col_names = chara.Properties.VariableNames(1:2);
        fram_num=height(chara);
        for col=1:2
            buff_chara = chara.(col_names{col});
            buff_chara(bad_predict_logical) = nan;
            buff_chara = fillmissing(buff_chara, 'linear','SamplePoints',1:fram_num);
            buff_chara=smoothdata(buff_chara,'gaussian',sm_win);
            chara.(col_names{col}) =buff_chara;
        end 
        bv_sm.(chara_names{i})=chara;
    end
end
function FunAddPath()
    script_full_path=mfilename('fullpath');
    [scriptpath, ~, ~] = fileparts(script_full_path);
    function_folder=fullfile(scriptpath,'function');
    if isfolder(function_folder)
        addpath(genpath(function_folder));
        fprintf('已添加路径: %s\n', function_folder);
    else
        error('未发现function文件夹: %s', helperFolder);
    end
end
function [savepath,neuron_align]=FunLoadNeuronalign(rootpath)
    %读取neuron_align01.mat
    savepath=fullfile(rootpath,'res');
    neuron_align_file=fullfile(savepath,'neuron_align03.mat');
    if ~isfile(neuron_align_file)
        error('没找到neuron align03.mat 文件')
    end
    load(neuron_align_file,'neuron_align');
end