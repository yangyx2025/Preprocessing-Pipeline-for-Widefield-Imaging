% 图像配准与裁剪处理工具v1.0.0(版本号，更新后更改）
%适用16bit tif图
%yyx20250408
%yyx20250624 拆分成两部分，此为2nd，运行完1st后运行，注意refpath要与1st一致
%先转换align，全部转换完毕后，再移动原始图像
clc;clear;close all
FunAddPath()
disp('=== 图像配准与裁剪处理ing ===');
%% 设置基本信息
%设置参考路径
refpath='L:\m0415\20250510\image';
%设置待处理图像路径
preprocess_path={
    'L:\m0415\20250511\image';
    'L:\m0415\20250512\m0415';
    'L:\m0415\20250515\m0415';
    'L:\m0415\20250516\m0415';
    'L:\m0415\20250517\m0415';
    'L:\m0415\20250604\m0415';
    'L:\m0415\20250605\m0415';
    'L:\m0415\20250606\m0415';};
%参数设置
config = struct();
config.imshow_factor_mov = 2;  % 手动配准时图像亮度
config.imshow_factor_fix = 2;   % 手动配准时图像亮度
config.bg_subtract_factor = 0.8;    %去背景时选择的系数
sessions_num=length(preprocess_path);%需要配准的session数目
%% 读取参考文件
FuncCheckFolder(refpath,preprocess_path);
[ref_img,~]=FunLoadRefData(refpath);
%% 读取para并根据配准参数处理图像序列
for i=6:sessions_num
    para=FunLoadPara(preprocess_path{i});
    FunProcessImg(para,ref_img,preprocess_path{i},config,i);
end
%% function
function FuncCheckFolder(refpath,preprocess_path)
    if ~isfolder(refpath)
        error('参考路径不存在：%s', refpath);
    end
    for i = 1:length(preprocess_path)
        if ~isfolder(preprocess_path{i})
            error('待处理路径不存在：%s', preprocess_path{i});
        end
    end
end
function FunAddPath()
    script_full_path=mfilename('fullpath');
    [scriptpath, ~, ~] = fileparts(script_full_path);
    function_folder=fullfile(scriptpath,'function');
    if isfolder(function_folder)
        addpath(genpath(function_folder));
        fprintf('Added folder to path: %s\n', function_folder);
    else
        error('未发现function文件夹: %s', function_folder);
    end
end

function para=FunLoadPara(filepath)
    %读取配准参数
    para_file=fullfile(filepath,'align','para.mat');
    if ~isfile(para_file)
        error('路径中未发现para.mat文件');
    end
    buff=load(para_file, 'para');
    para=buff.para;
end
function FunProcessImg(para,ref_image,filepath,config,session_id)
    %逐张处理图片
    ref_crop=ref_image(para.crop_range(1):para.crop_range(2),...
        para.crop_range(3):para.crop_range(4));
    [h,w]=size(ref_crop);
    % 初始化投影矩阵
    max_proj = zeros(h, w, 'like', ref_crop);
    min_proj = ones(h, w, 'like', ref_crop) * intmax(class(ref_image));
    sum_proj = zeros(h, w, 'double');
    %逐张处理
    info=dir(fullfile(filepath,'*.tif'));
    if isempty(info)
        error('路径中未找到任何TIF图像文件');
    end
    info=natsortfiles(info);
    % 创建进度条，开始对每张图进行仿射变换
    h_wait = waitbar(0, sprintf('Session%d图像配准中，处理进度: 0%%',session_id));
    for i=1:length(info)
        img_file=fullfile(info(i).folder,info(i).name);
        img=imread(img_file);
        
        %仿射变换
        moving_img=imwarp(img,para.tform,'OutputView',imref2d(size(ref_image)));
        %crop
        res_img=moving_img(para.crop_range(1):para.crop_range(2),...
                para.crop_range(3):para.crop_range(4));
        %迭代计算最值结果
        max_proj = max(max_proj, res_img);
        min_proj = min(min_proj, res_img);
        sum_proj = sum_proj + double(res_img);
        %存储变换结果
        savefull=fullfile(para.savepath{2},['align_',info(i).name]);
        imwrite(uint16(res_img),savefull);
        align_progress=i/numel(info);
        waitbar(align_progress, h_wait, sprintf('Session%d图像配准中，处理进度: %.1f%%',...
            session_id,align_progress*100));
    end
    close(h_wait)
    %计算背景及极值图
    image_avr=sum_proj/length(info);
    image_de_bg=double(max_proj)-config.bg_subtract_factor*image_avr;
    imwrite(max_proj, fullfile(para.savepath{3},'max_image.tif'));
    imwrite(min_proj, fullfile(para.savepath{3},'min_image.tif'));
    imwrite(uint16(image_avr), fullfile(para.savepath{3},'avr_image.tif'));
    imwrite(uint16(image_de_bg), fullfile(para.savepath{3},'de_bg.tif'));
    %转移原始图像
    h_wait = waitbar(0, sprintf('Session%d图像配准中，处理进度: 0%%',session_id));
    for i=1:length(info)
        %转移rawdata
        img_file = fullfile(info(i).folder, info(i).name);
        try
            movefile(img_file,fullfile(para.savepath{1},info(i).name));
        catch
            disp([fullfile(para.savepath{1},info(i).name),'  移动失败'])
            keyboard
        end
        align_progress=i/numel(info);
        waitbar(align_progress, h_wait, sprintf('Session%d原始图像转移中，处理进度: %.1f%%',...
            session_id,align_progress*100));
    end
    close(h_wait)
end
function [ref_img,crop_range]=FunLoadRefData(refpath)
    %读取裁切范围
    range_file = fullfile(refpath, 'crop', 'crop_range.mat');
    if ~isfile(range_file)
        error('路径中未发现range.mat文件');
    end
    load(range_file, 'crop_range');
    %读取参考配准模板
    fixed_image_list=dir(fullfile(refpath,'raw','*.tif'));

    if isempty(fixed_image_list)
        error('路径中未找到参考TIF图像文件');
    end
    ref_img=imread(fullfile(fixed_image_list(1).folder,fixed_image_list(1).name));
end



