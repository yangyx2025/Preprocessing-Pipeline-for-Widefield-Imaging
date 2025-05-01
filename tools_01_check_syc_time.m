%yyx 20250429
%用于检测胡须刺激等时间间隔是否正常
clear;clc;close all
tdms_path='H:\syc_test\20250429';
tdms_name='demo_01_conv';
voltage_th=2.5;
FunAddPath();
daq_data=FunLoadDAQData(tdms_path,tdms_name);
syc_data=FunProcessSycData(daq_data);%整合数据到结构体
syc_event=FunConv2Event(syc_data,voltage_th);%检测同步文件中高低电平边沿
sti_timepoint_matrix=FunGetStiTimepointMatrix(syc_event,1000);

%% 
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
function DAQ_data=FunLoadDAQData(tdms_path,tdms_name)
    
    %load tdms
    tdms_file=fullfile(tdms_path,strcat(tdms_name,'.tdms'));
    if ~isfile(tdms_file)
        error('没找到转化的tdms 文件')
    end
    
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
function sti_timepoint_matrix=FunGetStiTimepointMatrix(syc_event,daq_rate)
    wh_event=syc_event.wh_event;
    trial_num=length(wh_event)/4;
    fprintf('检查到%d个胡须刺激trial\n',trial_num);
    sti_edge_timepoint_matrix=reshape(wh_event,4,trial_num)';
    sti_timepoint_matrix=nan(trial_num-1,4);
    for i=1:size(sti_edge_timepoint_matrix,1)-1%去掉最后一个trial防止不完整
        sti_timepoint_matrix(i,1)=sti_edge_timepoint_matrix(i,1);
        sti_timepoint_matrix(i,2)=sti_edge_timepoint_matrix(i,3);
        sti_timepoint_matrix(i,3)=sti_edge_timepoint_matrix(i,4);
        sti_timepoint_matrix(i,4)=sti_edge_timepoint_matrix(i+1,1)-1;
    end
    %更新时间
    sti_timepoint_matrix=sti_timepoint_matrix./daq_rate;
end


