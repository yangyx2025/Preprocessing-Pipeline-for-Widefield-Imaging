%读取cnmf-e结果
% yyx20250413 v1.0.0
clear;
clc;
close all;
filepath='K:\m0728\20240828_sleep_sti';
%% 
filename='export.hdf5';
savename='neuron_align01.mat';
savepath=filepath;
member_num=7;
n=0;
txt_name=fullfile(filepath,'export_list.txt');
fullname=fullfile(filepath,filename);
exportlist=FunReadHdf5Txt(txt_name);
for i=1:length(exportlist)
    if strcmp(exportlist{i,2},'unselected_good')
        if ~isempty(exportlist{i,3})
            hdf5_name=['/',exportlist{i,1},'/',exportlist{i,2},'/',exportlist{i,3}];
            n=n+1;
            patch_id=ceil(n/member_num);
            member_id=mod(n,member_num);
            neuron_patch(patch_id).id=exportlist{i,1};
            switch member_id
                case 1
                    neuron_patch(patch_id).center=h5read(fullname,hdf5_name);
                case 2
                    neuron_patch(patch_id).trace=h5read(fullname,hdf5_name);
                case 3
                    neuron_patch(patch_id).p_cnn=h5read(fullname,hdf5_name);
                case 4
                    neuron_patch(patch_id).p_corr=h5read(fullname,hdf5_name);
                case 5
                    neuron_patch(patch_id).patch_id=h5read(fullname,hdf5_name);
                case 6
                    neuron_patch(patch_id).spike=h5read(fullname,hdf5_name);
                case 0
                    neuron_patch(patch_id).p_snr=h5read(fullname,hdf5_name);
            end
        end
    end

end

%% intergration
neuron_align.neuron.trace=[]; 
neuron_align.neuron.location=[];
neuron_align.neuron.spike=[];
neuron_align.neuron.p_snr=[];
neuron_align.neuron.patch_id=[];
neuron_align.neuron.p_corr=[];
neuron_align.neuron.p_cnn=[];
neuron_align.neuron.patch=[];
neuron_align.neuron.para=h5read(fullname,'/param');
for i=1:patch_id
    location_buff=neuron_patch(i).center;
    trace_buff=neuron_patch(i).trace;
    spike_buff=neuron_patch(i).spike;
    patch_id_buff=neuron_patch(i).patch_id;
    p_snr_buff=neuron_patch(i).p_snr;
    p_corr_buff=neuron_patch(i).p_corr;
    p_cnn_buff=neuron_patch(i).p_cnn;
    num=length(p_cnn_buff);
    patch_num=str2double(neuron_patch(i).id(isstrprop(neuron_patch(i).id,'digit')));
    patch_buff=ones(num,1)*patch_num;
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

save(fullfile(savepath,savename2),'neuron_align','-v7.3');
% h5disp(fullname)
% h5read(fullname,'/patch1/unselected_good');


function exportlist=FunReadHdf5Txt(txt_name)
    opts = delimitedTextImportOptions("NumVariables", 3);

% 指定范围和分隔符
opts.DataLines = [1, Inf];
opts.Delimiter = "/";

% 指定列名称和类型
opts.VariableNames = ["param", "VarName2", "VarName3"];
opts.VariableTypes = ["char", "char", "char"];

% 指定文件级属性
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% 指定变量属性
opts = setvaropts(opts, ["param", "VarName2", "VarName3"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["param", "VarName2", "VarName3"], "EmptyFieldRule", "auto");

% 导入数据
exportlist = readtable(txt_name, opts);
exportlist = table2cell(exportlist);
numIdx = cellfun(@(x) ~isnan(str2double(x)), exportlist);
exportlist(numIdx) = cellfun(@(x) {str2double(x)}, exportlist(numIdx));
clear opts

end