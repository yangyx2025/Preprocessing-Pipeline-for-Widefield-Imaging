% 图像配准与裁剪处理工具v1.0.0(版本号，更新后更改）
%适用16bit tif图
%yyx20250408
%yyx 20250624 拆分为两个1st和2nd，方便小白操作，先运行1st存储tform等相关参数，再运行2nd进行图像变换
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
    'L:\m0415\20250606\m0415';
    };
%参数设置
config = struct();
config.imshow_factor_mov = 5;  % 手动配准时图像亮度
config.imshow_factor_fix = 5;   % 手动配准时图像亮度
config.bg_subtract_factor = 0.8;    %去背景时选择的系数
sessions_num=length(preprocess_path);%需要配准的session数目
%% 读取参考文件
FuncCheckFolder(refpath,preprocess_path);
[ref_img,crop_range]=FunLoadRefData(refpath);
%% 读取待配准图片并手动与模板配准
clc

for i=6:sessions_num
    clearvars movingPoints fixedPoints
    warning('off')
    savepath=FunCreateDirs(preprocess_path{i});
    warning('on')
    moving_img=LoadMovingImg(preprocess_path{i});
    %建立空para
    para=struct;
    para.crop_range=crop_range;
    para.refpath=refpath;
    %读取旧para
    para_old=FunLoadPara(preprocess_path{i});
    if isempty(para_old)
        cpselect(moving_img.*config.imshow_factor_mov,ref_img.*config.imshow_factor_fix);
        disp('请在 cpselect 界面中导出点对，然后继续运行...');
        keyboard;  % 等待用户导出点对并输入任意键继续
    else
        movingPoints=para_old.movingPoints;
        fixedPoints=para_old.fixedPoints;
        cpselect(moving_img.*config.imshow_factor_mov,ref_img.*config.imshow_factor_fix,...
            movingPoints,fixedPoints);
        fprintf('当前为session%d，之前已标记过，如无问题那么将继续下一个session\n',i);
        keyboard
    end
    tform = fitgeotrans(movingPoints,fixedPoints,'affine');
    para.movingPoints=movingPoints;
    para.fixedPoints=fixedPoints;
    para.tform=tform;
    para.savepath=savepath;
    save(fullfile(savepath{2},'para.mat'),'para');
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
        para=[];
        return
    end
    buff=load(para_file, 'para');
    para=buff.para;
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
    moving_img=imread(fullfile(info_mov(500).folder,info_mov(500).name));
end


