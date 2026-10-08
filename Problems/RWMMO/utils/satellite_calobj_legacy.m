function Population = satellite_calobj_legacy(Population,Problem)
% ���������ڼ�����Ⱥ�����Ŀ�꺯��ֵ
% global Problem
% Population = Init(PopSize,Problem);

N = length(Population);
[~,sat_sort] = sort(Problem.Preq,'desc');

for i=1:N
    laplist = Population(i).laps;
    equips = Population(i).equip;
    
    %% ����Ŀ�꺯��ֵ
    con = 0; % Υ��Լ�����
    detail = '';
    
    %% ��ȡ�������������Ϣ
    nTask = sum(Problem.NeedLap);
    task_info = zeros(nTask,5);
    task = 1;
    for sat = 1:Problem.Nreq
        for lapi = 1:Problem.NeedLap(sat)
            lap = laplist{sat}(lapi);
            equip = equips{sat}(lapi);
            ind = sum(Problem.Nlap(1:(sat-1)))+lap;
            task_info(task,1) = sat;
            task_info(task,2) = lap;
            task_info(task,3) = equip;
            task_info(task,4) = Problem.tStart(ind,equip);
            task_info(task,5) = Problem.tEnd(ind,equip);
            task = task+1;
        end
    end
    
    %% ����Լ���������
    isExe = ones(1,Problem.Nreq);
    for sat=1:Problem.Nreq
        laps = laplist{sat};
        lift = Problem.islift(sat,laps);
        
        start_time = task_info(sum(Problem.NeedLap(1:(sat-1)))+1:sum(Problem.NeedLap(1:(sat))),4);
        if any(start_time==0)
            isExe(sat) = 0;
            detail = [detail '����' num2str(sat) ',���ɼ�;'];
        end
        
        if sum(lift)<Problem.nLift(sat)
            isExe(sat) = 0;
            detail = [detail '����' num2str(sat) ',����Ȧ�β���;'];
        end
        if numel(find(lift==0))<Problem.nDesc(sat)
            isExe(sat) = 0;
            detail = [detail '����' num2str(sat) ',����Ȧ�β���;'];
        end
    end
    
    %% �����ͻ���
    equip_info = cell(Problem.Nequ,1);
    for sati=1:numel(sat_sort)
        old_equip_info = equip_info;
        sat = sat_sort(sati);
        if isExe(sat)==0 %���������ǵ�����ִ��
            continue
        end
        for lapi = 1:Problem.NeedLap(sat)
            lap = laplist{sat}(lapi);
            task = sum(Problem.NeedLap(1:(sat-1)))+lapi;
            
            equip = task_info(task,3);
            if isempty(equip_info{equip})
                equip_info{equip} = [task_info(task,4:5) sat];
            else
                for ind = 1:size(equip_info{equip},1)
                    d1 = equip_info{equip}(ind,:);
                    d2 = task_info(task,4:5);
                    flag = (d2(1)>d1(1) && d2(1)<d1(2)+360)|| ...
                        (d2(2)+360>d1(1) && d2(2)<d1(2)) || ...
                        (d2(1)<d1(1) && d2(2)>d1(2));
                    
                    if flag %˵���г�ͻ
                        % ��ǰ������Ȧ��ʱ�����Ѿ����źõ����Ƿ����˳�ͻ����Ҫ����ǰ����������Ϊ��ִ��
                        detail = [detail '����' num2str(sat) 'Ȧ��' num2str(lap) '������ͻ;'];
                        isExe(sat)=0;
                    end
                end
                equip_info{equip} = [equip_info{equip}; task_info(task,4:5) sat];
            end
        end
        if isExe(sat)==0
            equip_info = old_equip_info;
        end
        
    end
    
    finish_time = 0; % �������ʱ��
    for equ=1:Problem.Nequ
        if ~isempty(equip_info{equ})
            [~,ind] = sort(equip_info{equ}(:,1));
            equip_info{equ} = equip_info{equ}(ind,:);
            if equip_info{equ}(end,2)>finish_time
               finish_time = equip_info{equ}(end,2);
            end
        end
    end
    
    total_profit = 0;
    for task=1:nTask
        total_profit = total_profit + isExe(task_info(task,1)) * Problem.profits(task_info(task,1),task_info(task,3));
    end
    
    %% ����Ŀ�꺯��ֵ
    f = isExe; %��ؼƻ���ɱ���
    w1 = 5; w2 = 5; %ģ���е�Ȩ�����������Ե���
    % Reward assembly: [priority-and-profit reward; -finish time]. The whole
    % vector is negated again below (legacy double negation), so the returned
    % objectives are [-reward, +finish_time] - both minimised, f2 positive.
    obj = [w1*sum(Problem.Preq(1:Problem.Nreq).*f) + w2*total_profit; -finish_time];

    %% ��װ����
    Population(i).obj = -obj; %ԭĿ��Ϊ��󻯣���������С�������ȡ����
%     Population(i).obj = -obj; %ԭĿ��Ϊ��󻯣���������С�������ȡ����
    Population(i).con = con;
    Population(i).detail = detail;
    Population(i).f = f;
    Population(i).total_profit = total_profit;
    Population(i).task_info = task_info;
    Population(i).equip_info = equip_info;
end
