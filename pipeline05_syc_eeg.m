%yyx 20250430读取eeg
%yyx 20250503 整合加入eegscore
%yyx 20250713 优化数据结构；将睡眠状态得分转为string
%eeg需要三个通道
% clear;clc;
disp('=== 读取EEGing ===');
FunAddPath()
%% 参数设置
rootpath='K:\m0728\20240828_sleep_sti';
eeg_voltage_th=1.3;%检测event的阈值，mv
th_during=300;%event 间隔阈值，ms(设置为略宽于event脉冲即可)
eeg_sample_rate=1000;
%% 读取数据
%读取neuron_align
[savepath,neuron_align]=FunLoadNeuronalign(rootpath);
%读取eegdata
eeg_data=FunLoadEEGData(rootpath);
%读取eeg score
eeg_score=FunLoadEEGScore(rootpath);
%% 检测event
event_id=FunCheckEvent(eeg_data,eeg_voltage_th,th_during,eeg_sample_rate);
keyboard
%% 截取数据
eeg_data_syc=FunCutEEGData(eeg_data,event_id);
%% 判断每帧图像所处的状态，创建label
eeg_score(:,1)=eeg_score(:,1)-eeg_data.time(event_id(1));%同步状态标签的时间
sleep_score=FunAlignEEGScore(eeg_score,neuron_align.neuron.cam_time);
%% 整合数据
neuron_align=FunDataIntergration(neuron_align,eeg_data_syc,sleep_score);
%% 保存数据

save(fullfile(savepath,'neuron_align03.mat'),'neuron_align','-v7.3');

%% 
function neuron_align=FunDataIntergration(neuron_align,eeg_data_syc,sleep_score_number)
    neuron_align.eeg_data=eeg_data_syc;
    sleep_score_string=categorical(Trans2Column(sleep_score_number),[1 2 3],["wake" "nrem" "rem"]);
    neuron_align.score.eeg_score=sleep_score_string;
end
function eeg_data=FunLoadEEGData(filepath)
    eeg_filepath=fullfile(filepath,'eeg');
    info=dir(fullfile(eeg_filepath,'*.txt'));
    if isempty(info)
        error('未发现eeg文件')
    end
    info= natsortfiles(info);
    eeg_data=[];
    for i=1:length(info)
        eegfile=fullfile(info(i).folder,info(i).name);
        eegdata_fragement=FunLoadEEGTxt(eegfile);
        eeg_data=[eeg_data;eegdata_fragement];
    end
end
function output=FunLoadEEGTxt(eegfile)
    % 自动检测导入选项
    opts = detectImportOptions(eegfile, ...
        'Delimiter',{' ','\t'}, ...            % 空格或制表符都当分隔符
        'MultipleDelimsAsOne',true);           % 连续多个分隔符当成一个
    % 指定变量名和类型（可选，但能保证单位符号被去掉后仍读为数值）
    opts.VariableNames = {'time','eeg','emg','event'};
    opts.SelectedVariableNames = opts.VariableNames;
    output= readtable(eegfile, opts);
end
function FunAddPath()
    script_full_path=mfilename('fullpath');
    [scriptpath, ~, ~] = fileparts(script_full_path);
    function_folder=fullfile(scriptpath,'function');
    if isfolder(function_folder)
        addpath(genpath(function_folder));
        fprintf('Added folder to path: %s\n', function_folder);
    else
        error('未发现function文件夹: %s', helperFolder);
    end
end
function [savepath,neuron_align]=FunLoadNeuronalign(rootpath)
    %读取neuron_align01.mat
    savepath=fullfile(rootpath,'res');
    neuron_align_file=fullfile(savepath,'neuron_align02.mat');
    if ~isfile(neuron_align_file)
        error('没找到neuron align02.mat 文件')
    end
    load(neuron_align_file);
end
function event_time=FunCheckEvent(eeg_data,th,th_during,eeg_sample_rate)
    %检测event
    event=eeg_data.event;
    event_time=FunGetEventTransitionPoint(event,'up',th);
    if isempty(event_time)
        error('未见event')
    elseif numel(event_time)==1
        error('只有一个event')
    end
    %特殊事件标记
    fprintf('注意：检测到%d个event！\n',numel(event_time));
    %由于波形震荡，导致一次脉冲中检测到多个event，根据event间隔筛选
    event_time=FunCheckEventInterval(event_time,th_during,eeg_sample_rate);
    fprintf('注意：去掉小间隔event后检测到%d个event！\n',numel(event_time));
    disp('确认无问题后继续运行。')
end
function event_time=FunCheckEventInterval(event_time,th_during,eeg_sample_rate)
    th_during=th_during/eeg_sample_rate;
    event_time_diff=diff(event_time)./eeg_sample_rate;
    event_time(find(event_time_diff<th_during)+1)=[];
end
function state=FunLoadEEGScore(rootpath)
    score_path=fullfile(rootpath,'eeg','sleepscore*.mat');
    info=dir(score_path);
    if isempty(info)
        error('未发现睡眠评分文件')
    else
        fprintf('发现%d个睡眠评分文件，将按照文件名选取最后一个\n',numel(info))
    end
    info=natsortfiles(info);
    eeg_score_file=fullfile(info(end).folder,info(end).name);
    load(eeg_score_file,'state');%读取state
end
function eeg_data_syc=FunCutEEGData(eeg_data,event_id)
    eeg_data_syc=eeg_data(event_id(1):event_id(end),:);
    eeg_data_syc.time=eeg_data_syc.time-eeg_data_syc.time(1);
end
function sleep_score=FunAlignEEGScore(eeg_score,cam_time)
    %根据时间为每帧图像建立状态标签
    %要求输入时间为单调递增
    sleep_score = interp1(eeg_score(:,1), eeg_score(:,2), cam_time, ...
                          'nearest', 'extrap');
end
