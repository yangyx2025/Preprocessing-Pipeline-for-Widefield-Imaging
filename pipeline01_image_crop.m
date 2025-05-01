%yyx20250413 版本v1.0.0
%1，适用16bit tif图
clear; clc; close all;
FunAddPath()
disp('=== 图像裁切处理ing ===');
rootpath='D:\yyx\cam\20230616\m0606_iso\image';
range_raw=[36	135	1956	1587];%[bx by width height]; 来自imagej

%% 
crop_range=[range_raw(2),range_raw(2)+range_raw(4),range_raw(1),range_raw(1)+range_raw(3)];
bg_subtract_factor=0.8;
filepath=FunCreatFilepath(rootpath);
save(fullfile(savepath{2},'crop_range.mat'),'crop_range');
%% 裁切每张图片
FunProcessImg(crop_range,filepath,bg_subtract_factor);

%% function
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
function filepath=FunCreatFilepath(rootpath)
    filepath=cell(4,1);
    dirs = {'raw', 'crop', 'de_bg'};
    for i = 1:numel(dirs)
        filepath{i}=fullfile(rootpath, dirs{i});
        mkdir(filepath{i});
    end
    filepath{4}=rootpath;
end
function FunProcessImg(crop_range,filepath,bg_subtract_factor)
    %读取图像目录
    info=dir(fullfile(filepath{4},'*.tif'));
    if isempty(info)
        error('路径中未找到任何TIF图像文件');
    end

    %排列图像
    info=natsortfiles(info);
    ref_img=imread(fullfile(info(1).folder,info(1).name));

    % 初始化投影矩阵
    try
        ref_crop=ref_image(crop_range(1):crop_range(2),...
            crop_range(3):crop_range(4));
    catch
        error('裁剪范围超出图像尺寸');
    end
    [h,w]=size(ref_img);
    max_proj = zeros(h, w, 'like', ref_crop);
    min_proj = ones(h, w, 'like', ref_crop) * intmax(class(ref_img));
    sum_proj = zeros(h, w, 'double');
    
    % 创建进度条
    h_wait = waitbar(0, '图像处理中,处理进度: 0%');
    %逐张处理
    for i=1:length(info)
        %读取原始图片
        img_file=fullfile(info(i).folder,info(i).name);
        img=imread(img_file);
        res_img=img(crop_range(1):crop_range(2),crop_range(3):crop_range(4));
        %迭代计算最值结果
        max_proj = max(max_proj, res_img);
        min_proj = min(min_proj, res_img);
        sum_proj = sum_proj + double(res_img);
        %存储裁切结果
        savefull=fullfile(filepath{2},['crop_',info(i).name]);
        imwrite(res_img,savefull);
        %转移rawdata
        try
            movefile(img_file,fullfile(filepath{1},info(i).name));
        catch
            disp([fullfile(para.savepath{1},info(i).name),'  移动失败'])
        end
        crop_progress=i/numel(info);
        waitbar(crop_progress, h_wait, sprintf('图像处理中,处理进度: %.1f%%', crop_progress*100));
    end
    close(h_wait)
    %计算平均以及背景扣除
    image_avr=sum_proj/length(info);
    image_de_bg=double(max_proj)-bg_subtract_factor*image_avr;
    %保存结果
    imwrite(max_proj, fullfile(filepath{3},'max_image.tif'));
    imwrite(min_proj, fullfile(filepath{3},'min_image.tif'));
    imwrite(uint16(image_avr), fullfile(filepath{3},'avr_image.tif'));
    imwrite(uint16(image_de_bg), fullfile(filepath{3},'de_bg.tif'));
end