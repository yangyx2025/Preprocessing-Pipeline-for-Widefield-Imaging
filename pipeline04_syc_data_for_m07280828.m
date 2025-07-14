%yyx 20250421 单个相机/胡须刺激
%特殊版本，m0728 0828次session将event开始在了胡须刺激之后
%输出版本中保留事件之间的sti_time，并将syc.event删减到事件之间
%运行时注意daq通道的对应意义是否一致；
%ai0:event/ai1:calcium image/ai2:bahavior video1/ai3:whisker
clear;clc;
disp('=== 数据同步处理ing ===');
FunAddPath()
%% 参数设置
rootpath='K:\m0728\20240828_sleep_sti';
cam_framerate=10;
voltage_th=1;%用于检测边沿的阈值
daq_sample_rate=1000;
%% 读取并简单整合
%读取neuron_align
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
%% 截取有效数据
neuron_align=FunGetEffectFrame(neuron_align,syc_event);
[sti,syc_event]=FunGetEffectSTI(syc_event,neuron_align.conf.daq_samplerate);
%% 整合结果
neuron_align.sti=sti;
neuron_align.syc_event=syc_event;
%% 
keyboard
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
function [sti,syc_event]=FunGetEffectSTI(syc_event,daq_rate)
    %获取胡须刺激时间矩阵
    wh_event=syc_event.wh_event;
    [trial_time,trial_type]=FunGetStiTimepointMatrix(wh_event);
    %截取实验事件之间的胡须刺激
    id_start=find(trial_time(:,1)>syc_event.exp_event(1),1);%检查实验事件之后的第一个胡须刺激
    id_end=size(trial_time,1);%最后的胡须刺激在事件结束之前
    trial_time=trial_time(id_start:id_end,:);
    trial_type=trial_type(id_start:id_end);
    %截取实验事件中的胡须刺激
    eff_sti_event_start_id=find(syc_event.wh_event==trial_time(1,1));
    syc_event.wh_event=syc_event.wh_event(eff_sti_event_start_id:end);

    %最后更新sti的相对时间矩阵,单位s
    trial_time=(trial_time-syc_event.exp_event(1))./daq_rate;
    sti=struct('trial_time',trial_time, ...
        'trial_type',trial_type);
end
function [trial_time,trial_type]=FunGetStiTimepointMatrix(wh_event)
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
    trial_type_number=round(diff(sti_edge_timepoint_matrix(:,1:2),1,2)./100);%将刺激类型作为数值存储
    if numel(unique(trial_type_number))>3
        error('trial type 超过三类')
    end
    trial_type=categorical(Trans2Column(trial_type_number),[1 2 3],["low" "medium" "high"]);

end
function [savepath,neuron_align]=FunLoadNeuronalign(rootpath)
    %读取neuron_align01.mat
    savepath=fullfile(rootpath,'res');
    neuron_align_file=fullfile(savepath,'neuron_align01.mat');
    if ~isfile(neuron_align_file)
        error('没找到neuron align 文件')
    end
    load(neuron_align_file,'neuron_align');
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
    function_folder=fullfile(scriptpath,'function');
    if isfolder(function_folder)
        addpath(genpath(function_folder));
        fprintf('Added folder to path: %s\n', function_folder);
    else
        error('未发现function文件夹: %s', helperFolder);
    end
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

