% 图像配准与裁剪处理工具v1.0.0(版本号，更新后更改）
%yyx20250408

clc;clear;close all
addpath('general function')
disp('=== 图像配准与裁剪处理ing ===');
%% 设置基本信息
%设置参考路径
refpath='L:\m1229\20250402\image';
%设置待处理图像路径
preprocess_path={
    'L:\m1229\20250404\image';
    'L:\m1229\20250406\image'};
%参数设置
config = struct();
config.imshow_factor_mov = 2;  % 手动配准时图像亮度
config.imshow_factor_fix = 2;   % 手动配准时图像亮度
config.bg_subtract_factor = 0.8;    %去背景时选择的系数
sessions_num=length(preprocess_path);%需要配准的session数目
%% 读取参考文件
[ref_img,crop_range]=FunLoadRefData(refpath);

%% 读取待配准图片并手动与模板配准
%重跑可注释掉本节运行
% 
para=struct;
para.crop_range=crop_range;
para.refpath=refpath;
for i=1:sessions_num
    savepath=FunCreateDirs(preprocess_path{i});
    moving_img=LoadMovingImg(preprocess_path{i});
    if exist('movingPoints', 'var') && exist('fixedPoints', 'var')&&i>1
        cpselect(moving_img.*config.imshow_factor_mov,ref_img.*config.imshow_factor_fix,...
            movingPoints,fixedPoints);
    else
        cpselect(moving_img.*config.imshow_factor_mov,ref_img.*config.imshow_factor_fix);
    end
    disp('请在 cpselect 界面中导出点对，然后在命令窗口按任意键继续...');
    pause;  % 等待用户导出点对并输入任意键继续
    tform = fitgeotrans(movingPoints,fixedPoints,'affine');
    para.movingPoints=movingPoints;
    para.fixedPoints=fixedPoints;
    para.tform=tform;
    para.savepath=savepath;
    save(fullfile(savepath{2},'para.mat'),'para');
end
%% 

%% 读取para并根据配准参数处理图像序列
for i=1:sessions_num
    para=FunLoadPara(preprocess_path{i});
    FunProcessImg(para,ref_img,preprocess_path{i},config,i);
end

%% function
function savepath=FunCreateDirs(base_path)
    % 创建标准化的输出目录
    savepath=cell(4,1);
    dirs = {'raw', 'align', 'de_bg'};
    for i = 1:numel(dirs)
        savepath{i}=fullfile(base_path, dirs{i});
        mkdir(savepath{i});
    end
    savepath{4}=base_path;
end
function para=FunLoadPara(filepath)
    %读取配准参数
    para_file=fullfile(filepath,'align','para.mat');
    if ~isfile(para_file)
        error('路径中未发现para.mat文件');
    end
    load(para_file, 'para');
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
    % 创建进度条
    h_wait = waitbar(0, 'Session%d图像配准中，处理进度: 0%',session_id);
    for i=1:length(info)
        img_file=fullfile(info(1).folder,info(i).name);
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
        %转移rawdata
        try
            movefile(img_file,fullfile(para.savepath{1},info(i).name));
        catch
            disp([fullfile(para.savepath{1},info(i).name),'  移动失败'])
        end
        align_progress=i/numel(info);
        waitbar(align_progress, h_wait, sprintf('Session%d图像配准中，处理进度: %.1f%%',...
            align_progress*100));
    end
    close(h)
    image_avr=sum_proj/length(info);
    image_de_bg=double(max_proj)-config.bg_subtract_factor*image_avr;
    imwrite(max_proj, fullfile(para.savepath{3},'max_image.tif'));
    imwrite(min_proj, fullfile(para.savepath{3},'avr_image.tif'));
    imwrite(uint16(image_avr), fullfile(para.savepath{3},'avr_image.tif'));
    imwrite(uint16(image_de_bg), fullfile(para.savepath{3},'de_bg.tif'));
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
function moving_img=LoadMovingImg(movpath)
    info_mov=dir(fullfile(movpath,'*.tif'));
    if isempty(info_mov)
        error('路径中未找到任何TIF图像文件');
    end
    moving_img=imread(fullfile(info_mov(1).folder,info_mov(1).name));
end


