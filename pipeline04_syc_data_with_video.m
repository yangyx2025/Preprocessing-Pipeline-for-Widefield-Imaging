%yyx 20250421 单个相机/胡须刺激
%yyx 20250430 增加识别刺激类型，保存为neuronalign02,防止出错时需要重新跑上一步
%运行时注意daq通道的对应意义是否一致；
%ai0:event/ai1:calcium image/ai2:bahavior video1/ai3:whisker
clear;clc;
disp('=== 数据同步处理ing ===');
FunAddPath()
%% 参数设置
rootpath='K:\m0728\20240830_sleep_sti';
cam_framerate=10;
voltage_th=1;%用于检测边沿的阈值
daq_sample_rate=1000;
%% 读取并简单整合
[savepath,neuron_align]=FunLoadNeuronalign(rootpath);
%set基础参数
neuron_align=FunSetConf(neuron_align,cam_framerate,voltage_th,daq_sample_rate);
%读取
daq_data=FunLoadDAQData(rootpath);%读取DAQ tdms文件
syc_data=FunProcessSycData(daq_data);%整合数据到结构体
syc_event=FunConv2Event(syc_data,voltage_th);%检测同步文件中高低电平边沿
FunCheckData(syc_event,neuron_align);%检查异常
disp('检查是否存在问题，无问题可继续运行');
keyboard
%% 转化胡须刺激格式（并更新时间）
sti=FunGetStiTimepointMatrix(syc_event,daq_sample_rate);
%% 截取有效数据
neuron_align=FunGetEffectFrame(neuron_align,syc_event);
neuron_align.sti=sti;
neuron_align.syc_event=syc_event;
%% 
% keyboard

%% 
save(fullfile(savepath,'neuron_align02.mat'),'neuron_align','-v7.3');





%% 
function neuron_align=FunSetConf(neuron_align,cam_framerate,voltage_th,daq_sample_rate)
    %设置采集参数
    neuron_align.conf.voltage_th=voltage_th;%电压
    neuron_align.conf.framerate_calcium=cam_framerate;
    neuron_align.conf.daq_samplerate=daq_sample_rate;
    fprintf('钙成像帧率设置为 %d Hz\n', neuron_align.conf.framerate_calcium);
    fprintf('阈值电压设置为 %.3f V\n', neuron_align.conf.voltage_th);
    fprintf('DAQ采样率设置为 %d Hz\n', daq_sample_rate);
end
function sti=FunGetStiTimepointMatrix(syc_event,daq_rate)
    wh_event=syc_event.wh_event;
    trial_num=length(wh_event)/4;
    fprintf('检查到%d个胡须刺激trial\n',trial_num);
    sti_edge_timepoint_matrix=reshape(wh_event,4,trial_num)';
    trial_time=nan(trial_num-1,4);
    for i=1:size(sti_edge_timepoint_matrix,1)-1%去掉最后一个trial防止不完整
        trial_time(i,1)=sti_edge_timepoint_matrix(i,1);
        trial_time(i,2)=sti_edge_timepoint_matrix(i,3);
        trial_time(i,3)=sti_edge_timepoint_matrix(i,4);
        trial_time(i,4)=sti_edge_timepoint_matrix(i+1,1)-1;
    end
    trial_type=round(diff(sti_edge_timepoint_matrix(:,1:2),1,2)./100);%将刺激类型作为数值存储
    %更新时间
    trial_time=(trial_time-syc_event.exp_event(1))./daq_rate;
    %刺激类型对应物理意义
    trial_type_label = struct( ...
        'low',    1, ...
        'medium', 2, ...
        'high',   3 ...
        );
    sti=struct('trial_time',trial_time, ...
        'trial_type',trial_type, ...
        'trial_type_label',trial_type_label);
end
function [savepath,neuron_align]=FunLoadNeuronalign(rootpath)
    %读取neuron_align01.mat
    savepath=fullfile(rootpath,'res');
    neuron_align_file=fullfile(savepath,'neuron_align01.mat');
    if ~isfile(neuron_align_file)
        error('没找到neuron align 文件')
    end
    load(neuron_align_file);
end
function DAQ_data=FunLoadDAQData(rootpath)
    %读取daq文件
    tdms_filepath=fullfile(rootpath,'syc');
    %load tdms
    info_tdms=dir(fullfile(tdms_filepath,'*conv.tdms'));
    if isempty(info_tdms)
        error('没找到转化的tdms 文件')
    end
    tdms_filename=info_tdms(1).name;
    tdms_file=fullfile(tdms_filepath,tdms_filename);
    [DAQ_data,~,~,~]=convertTDMS(true,tdms_file);
end
function FunAddPath()
    script_full_path=mfilename('fullpath');
    [scriptpath, ~, ~] = fileparts(script_full_path);
    addpath(fullfile(scriptpath,'function'));
end
function syc_data=FunProcessSycData(daq_data)
    %处理同步数据，转化为结构体
    for i=3:size(daq_data.Data.MeasuredData,2)
        channel_name=daq_data.Data.MeasuredData(i).Name;
        channelid = regexp(channel_name, 'ai\d+', 'match');
        channelid=channelid{1};
        switch channelid
            case 'ai0'%event
                syc_data.event=daq_data.Data.MeasuredData(i).Data;
            case 'ai1'%wide field image
                syc_data.image=daq_data.Data.MeasuredData(i).Data;
            case 'ai2'%行为相机1
                syc_data.bv=daq_data.Data.MeasuredData(i).Data;
            case 'ai3'%whisker
                syc_data.wh=daq_data.Data.MeasuredData(i).Data;
            otherwise
                continue
        end

    end
end
function syc_event=FunConv2Event(syc_data,th)
    %检测并整合边沿时间点
    syc_event=struct();
    %提取实验特殊事件标记
    syc_event.exp_event=FunGetEventTransitionPoint(syc_data.event,'up',th);
    %检测实验特殊事件标记
    syc_event.cam_event=FunGetEventTransitionPoint(syc_data.image,'up',th);
    %胡须刺激时间点提取
    syc_event.wh_event=FunGetEventTransitionPoint(syc_data.wh,'up&down',th);
    %行为视频
    syc_event.bv_event=FunGetEventTransitionPoint(syc_data.bv,'up',th);
end
function FunCheckData(syc_event,neuron_align)
    %异常检测
    %01掉帧检测
    frame_num=size(neuron_align.neuron.trace,2);
    cam_event=numel(syc_event.cam_event);
    fprintf('注意：检测到%d个帧数差异！！！！\n',abs(cam_event-frame_num));
    %特殊事件标记
    fprintf('注意：检测到%d个event！\n',numel(syc_event.exp_event));
    %检测胡须刺激是否完整（是否为4的倍数）
    if mod(numel(syc_event.wh_event),4) ~= 0
         disp('注意：胡须刺激事件并非4的倍数,可能不完整！！！！！');
    end
    %检测胡须刺激是否在event内部
    if syc_event.wh_event(1)<syc_event.exp_event(1)||syc_event.wh_event(end)>syc_event.exp_event(end)
        disp('注意：胡须刺激事件内部存在特殊事件标记，请确认是否存在问题！！！！！');
    end
end
function neuron_align=FunGetEffectFrame(neuron_align,syc_event)
    exp_event=syc_event.exp_event;
    cam_logical=syc_event.cam_event>exp_event(1)&syc_event.cam_event<exp_event(2);
    neuron_align.neuron.trace=neuron_align.neuron.trace(:,cam_logical);
    neuron_align.neuron.spike=neuron_align.neuron.spike(:,cam_logical);
    cam_time=syc_event.cam_event-exp_event(1);
    cam_time=cam_time(cam_logical);
    neuron_align.neuron.cam_time=cam_time./neuron_align.conf.daq_samplerate;
end

