%读取cnmf-e结果
% yyx20250413 v1.0.0
%yyx20250417 v1.1.0 switch 转为字典索引增加容错，优化了数据读取函数和代码逻辑
%yyx20250417 v1.1.1 增加动态字段索引，替换switch索引，简化代码
clear;
clc;
close all;
filepath='K:\m0728\20240828_sleep_sti\res';
%% 
exportlist_txt=fullfile(filepath,'export_list.txt');
hdf5file=fullfile(filepath,'export.hdf5');
%读取文件目录,生成patch的索引
[hdf5_filelist,patch_id]=FunReadHdf5Txt(exportlist_txt);

%% 依次读取目录内容并整合
patch_num=numel(unique(patch_id));
% 定义字段映射：HDF5 子名 -> neuron_patch 字段名
fieldMap = struct( ...
    'good_a',     'center', ...
    'good_c',     'trace', ...
    'good_cnn',   'p_cnn', ...
    'good_corr',  'p_corr', ...
    'good_patchid','neuron_id', ...
    'good_s',     'spike', ...
    'good_snr',   'p_snr' ...
);
neuron_patch = repmat(struct( ...
    'patch_id',   [], ...
    'center',     [], ...
    'trace',      [], ...
    'p_cnn',      [], ...
    'p_corr',     [], ...
    'neuron_id',   [], ...%neuron_id in one patch
    'spike',      [], ...
    'p_snr',      []  ...
), patch_num, 1);

for i=1:length(hdf5_filelist)
    %依次读取
    hdf5_name=['/',hdf5_filelist{i,1},'/',hdf5_filelist{i,2},'/',hdf5_filelist{i,3}];
    patch_id_buff=patch_id(i)+1;%python 与matlab index 转换
    neuron_patch(patch_id_buff).patch_id=patch_id(i);
    % 动态字段赋值
    fld = fieldMap.(hdf5_filelist{i,3});
    neuron_patch(patch_id_buff).(fld) = h5read(hdf5file,hdf5_name);
end

%% intergration整合到neuron_align
neuron_align.neuron.trace=[]; 
neuron_align.neuron.location=[];
neuron_align.neuron.spike=[];
neuron_align.neuron.p_snr=[];
neuron_align.neuron.patch_id=[];
neuron_align.neuron.p_corr=[];
neuron_align.neuron.p_cnn=[];
neuron_align.neuron.patch=[];
neuron_align.neuron.para=h5read(hdf5file,'/param');

for i=1:size(neuron_patch,1)
    location_buff=neuron_patch(i).center;
    trace_buff=neuron_patch(i).trace;
    spike_buff=neuron_patch(i).spike;
    patch_id_buff=neuron_patch(i).neuron_id;
    p_snr_buff=neuron_patch(i).p_snr;
    p_corr_buff=neuron_patch(i).p_corr;
    p_cnn_buff=neuron_patch(i).p_cnn;
    patch_buff=ones(length(p_cnn_buff),1)*neuron_patch(i).patch_id;

    neuron_align.neuron.trace=[neuron_align.neuron.trace;trace_buff'];
    neuron_align.neuron.location=[neuron_align.neuron.location;location_buff];
    neuron_align.neuron.spike=[neuron_align.neuron.spike;spike_buff'];
    neuron_align.neuron.p_snr=[neuron_align.neuron.p_snr;p_snr_buff];
    neuron_align.neuron.p_corr=[neuron_align.neuron.p_corr;p_corr_buff];
    neuron_align.neuron.p_cnn=[neuron_align.neuron.p_cnn;p_cnn_buff];
    neuron_align.neuron.patch_id=[neuron_align.neuron.patch_id;patch_id_buff];
    neuron_align.neuron.patch=[neuron_align.neuron.patch;patch_buff];
end
%% 
save(fullfile(filepath,'neuron_align.mat'),'neuron_align','-v7.3');
%% 
% h5disp(fullname)
% h5read(fullname,'/patch1/unselected_good');
%% 
function [res_cell_string,patch_ids] = FunReadHdf5Txt(txt_name)
    %读取hdf5的导出文件目录文本
    % 逐行读取、以 '/' 分割，再转为 cell 数组
    res_cell=readcell(txt_name, 'Delimiter', '/', 'TextType','string');
    res_cell_string=string(res_cell);
    res_cell_string(ismissing(res_cell_string))="";

    %去掉无关部分
    mask= strcmp(res_cell_string(:,2), 'unselected_good') & ~cellfun(@isempty, res_cell_string(:,3));
    res_cell_string = res_cell_string(mask, :);
    %读取patch id
    patch_ids   = cellfun(@(s) sscanf(s,'patch%d'), res_cell_string(:,1));
    
end