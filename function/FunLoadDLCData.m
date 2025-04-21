function output=FunLoadDLCData(filepath,filename,options)
%yyx20250417 读取deeplabcut输出csv
%example1:FunLoadDLCData(filepath,filename,'str',{'xxx','xxx'},'chara_logical',
% [0 1 0 1])将会使用四个特征点中的第2个和第4个并分别命名
%example2: FunLoadDLCData(filepath,filename,'str',{'xxx','xxx'})使用全部特征并命名
%example3:FunLoadDLCData(filepath,filename,'chara_logical',[0 1 0
%1])使用部分特征并使用默认命名
%example4:FunLoadDLCData(filepath,filename)使用全部特征并使用默认命名
    arguments
        %通过输入键值确定参数
        filepath
        filename    {mustBeNonzeroLengthText}
        options.str%特征名称
        options.chara_logical%0/1组合数列，决定使用哪些特征，特征数应与特征名称匹配
    end
   
    %读取deeplabcut 数据
    bv=readtable(fullfile(filepath,filename),'NumHeaderLines',1);
    %确定特征点数目
    chara_num=(size(bv,2)-1)/3;
    %查验待用特征点以及命名
    if isfield(options,'chara_logical')
        %是否只提取特定特征点
        chara_logical=options.chara_logical;
        if numel(chara_logical)~=chara_num
            error('特征逻辑值数量不匹配')
        else
            chara_id=find(chara_logical);
        end
        %有输入特征名称则用，无输入则使用默认名称
    else
        %如果没有此项输入，默认使用全部特征点
        chara_id=1:chara_num;
    end
    if isfield(options,'str')
        %是否提供了特征名称
        str=options.str;
        if numel(str)~=numel(chara_id)
            error('特征点名称数目与实际使用特征点数目不符')
        end
    else
        %没有提供特征点名称则使用默认标题名称
        str=cell(numel(chara_id),1);
        for i=1:length(chara_id)
            col_id=FunGetCharaFristColID(chara_id(i));
            str{i}=bv.Properties.VariableNames{col_id};
        end
    end
    output=struct();
    for i=1:numel(chara_id)
        buff_id=chara_id(i);
        x=bv(:,FunGetCharaFristColID(buff_id));
        y=bv(:,FunGetCharaFristColID(buff_id)+1);
        p=bv(:,FunGetCharaFristColID(buff_id)+2);
        output.(str{i})=[x,y,p];
        output.(str{i}).Properties.VariableNames={'x','y','p'};
    end
   
end
function col_id=FunGetCharaFristColID(num)
    %根据是第几个特征点，计算其在csv table中所在的列（x坐标所在列）
    col_id=(num-1)*3+2;
end
