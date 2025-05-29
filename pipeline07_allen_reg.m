%yyx 20250508 将神经元按照位置确定在ALlen图谱中的脑区
%neuron loc [x y] 其中x指的是图像矩阵的列，坐标轴的x；y指的是图像矩阵的行，坐标轴的y轴

clear;clc;
neuron_path='K:\m0728\20240828_sleep_sti\res';%神经元数据neuron_align的路径
isipath='K:\m0728\isi';%isi结果路径
%% 添加路径
function_folder=FunAddPath();
%% 数据读取
neuron_align=FunLoadNeuronalign(neuron_path);%读取neuron_align03.mat
[para,isi_img]=FunLoadISIRes(isipath);%读取isi结果
[allen_annotation_img,allen_annotation_edge,allen_csv]=FunLoadISIAnnotation(function_folder);%读取isi annotation文件
%% 
%获取用于配准的数据输入
[neuron_loc,allen_annotation_img_crop,tform]=FunISITransPrepare(neuron_align,allen_annotation_img,para);
%对每个神经元进行位置判断
[id,allen_x,allen_y]=FunGetNeuronCTXid(neuron_loc,allen_annotation_img_crop,tform);
%根据id判断脑区
ctx_res=FunChooseCTXArea(id,allen_csv);
%% 展示神经元
FunShowNeuron(ctx_res,allen_x,allen_y,allen_annotation_edge,para)
disp('确认无问题继续')
pause
%% 存储到mat文件
neuron_align.neuron.allen_loc=[allen_x,allen_y];
neuron_align.ctx_res=ctx_res;
save(fullfile(neuron_path,'neuron_align03.mat'),'neuron_align','-v7.3');

%% 
function FunShowNeuron(ctx_res,allen_x,allen_y,allen_annotation_edge,para)
    crop_range=para.allen_frame_range;
    allen_edge_img_crop=allen_annotation_edge(crop_range(1):crop_range(2),crop_range(3):crop_range(4));
    figure;
    imshow(allen_edge_img_crop);
    hold on
    for i=1:height(ctx_res)
        neuron_id=ctx_res.neuron_cluster_id{i};
        scatter(allen_x(neuron_id),allen_y(neuron_id));
    end
    
end
function ctx_res=FunChooseCTXArea(idx,allen_csv)
    %整合数据并判断脑区
    ctx_res=struct();
    id=unique(idx);
    for i=1:length(id)
        ctx_res.id(i,1)=id(i);
        ctx_res.neuron_cluster_id{i,1}=find(idx==id(i));
    end
    ctx_res.num=cellfun(@length,ctx_res.neuron_cluster_id);
    ctx_res=struct2table(ctx_res);

    for i=1:length(ctx_res.id)
        try
            csv_id=allen_csv.id==ctx_res.id(i);
        catch
            error('未发现对应的脑区')
        end
        ctx_name=allen_csv.acronym{csv_id};
        ctx_res.ctx_name{i,1}=ctx_name(1:end-1);%去掉layer1后缀
    end
end
function [id,allen_x,allen_y]=FunGetNeuronCTXid(neuron_loc,allen_annotation_img_crop,tform)
    %建立id
    id=nan(size(neuron_loc,1),1);
    %将tform 转为affine2d模式
    tform_aff = affine2d(tform);
    [new_x, new_y] = transformPointsForward(tform_aff, neuron_loc(:,1), neuron_loc(:,2));
    % 将坐标转换为图像索引（注意索引从1开始，并且必须是整数）
    allen_x = round(new_x);
    allen_y = round(new_y);

    % 限制索引范围以避免越界
    allen_x = max(min(allen_x, size(allen_annotation_img_crop,2)), 1);
    allen_y = max(min(allen_y, size(allen_annotation_img_crop,1)), 1);
    for i=1:size(neuron_loc,1)
        id(i,1)=allen_annotation_img_crop(allen_y(i),allen_x(i));
    end
end
function [neuron_loc,allen_annotation_img_crop,tform]=FunISITransPrepare(neuron_align,allen_annotation_img,para)
    %抽提神经元位置    
    neuron_loc=neuron_align.neuron.location;
    %crop isi annotation img
    crop_range=para.allen_frame_range;
    allen_annotation_img_crop=allen_annotation_img(crop_range(1):crop_range(2),crop_range(3):crop_range(4));
    %load tform
    tform=para.isi2allen_tform;
end
function [isi_img,isi_edge,allen_csv]=FunLoadISIAnnotation(function_folder)
    %从function folder中读取allen annotation的图像和csv
    isi_img_file=fullfile(function_folder,'allen_atlas','allen_top_annoation.tiff');
    if ~isfile(isi_img_file)
        error('路径%s中未发现allen annotation tiff\n',function_folder);
    else
        isi_img=imread(isi_img_file);
    end
    allen_csv_file=fullfile(function_folder,'allen_atlas','voxel_count_and_differences.csv');
    if ~isfile(isi_img_file)
        error('路径%s中未发现allen csv tiff\n',allen_csv_file);
    else
        allen_csv=readtable(allen_csv_file);
    end
    isi_edge_file=fullfile(function_folder,'allen_atlas','combine_edge_and_barrel.tif');
    if ~isfile(isi_edge_file)
        error('路径%s中未发现allen annotation edge\n',function_folder);
    else
        isi_edge=imread(isi_edge_file);
    end

end
function function_folder=FunAddPath()
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
function [para,isi_img]=FunLoadISIRes(isipath)
    %读取isi para文件
    info=dir(fullfile(isipath,'isi2allen*.mat'));
    if isempty(info)
        error('未发现isi的mat文件')
    else
        fprintf('发现%d个isi的mat文件，排序后取最后一个\n',numel(info));
        info= natsortfiles(info);
        isi_mat=fullfile(info(end).folder,info(end).name);
        load(isi_mat,'para')
    end
    %读取isi img
    isi_img_file=fullfile(isipath,'isi_rgb.tif');
    if ~isfile(isi_img_file)
        error('未发现isi_rab,tif文件')
    else
        isi_img=imread(isi_img_file);
    end
end
function neuron_align=FunLoadNeuronalign(rootpath)
    %读取neuron_align01.mat
    
    neuron_align_file=fullfile(rootpath,'neuron_align03.mat');
    if ~isfile(neuron_align_file)
        error('没找到neuron align03.mat 文件')
    end
    load(neuron_align_file,'neuron_align');
end
