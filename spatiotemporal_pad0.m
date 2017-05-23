cell_ids = [35 105 147];%Inputweekend = 0;numdays = 4;trainDays = 3;numZones = 3;traj = [];time = [];traj2 = [];time2 = [];dow = [];% Construct distance matrix between cells% columns are cellid, centroid_x, centroid_y, etccelldata = csvread('cell_info_2.0km_priority.csv',2,0);numCells = length(celldata);distance = zeros(numCells);for i = 1:numCells    for j = 1:numCells        if i == j            distance(i,j) = 10000;        else            distance(i,j) = sqrt((celldata(i,2)-celldata(j,2))^2 + (celldata(i,3) - celldata(j,3))^2);        end       endendfor q = 1:length(cell_ids)    cell_id = cell_ids(q);        traj = [];    time = [];    traj2 = [];    time2 = [];    dow = [];    % Retrieve indexes of the nearest numZones cells    minIndex = zeros(numCells,numZones);    for i = 1:numCells        [~,d] = sort(distance(i,:));        minIndex(i,:) = d(1:numZones);    end    neighbourcell = minIndex(cell_id,:);    coordx = repmat(celldata(cell_id,2),283*numdays,1);    coordy = repmat(celldata(cell_id,3),283*numdays,1);    for i = 1:numZones        coordx = [coordx;repmat(celldata(neighbourcell(i),2),283*numdays,1)];        coordy = [coordy;repmat(celldata(neighbourcell(i),3),283*numdays,1)];    end            % Read in Data    for date = 1:numdays        if (date < 10)             d = strcat('0',num2str(date));        else            d = num2str(date);        end                % columns are cell_id,time_id,start_time,end_time,num_traj,inflow,outflow,avg_traveldist_km,avg_traveltime_min,avg_speed_kph        data = csvread(strcat('node_measures_2km_30min_5min_201603',d,'.csv'),2,1);                % Take out weekends (optional depending on needs)    %    if weekday(strcat('2016-03-',d)) == 1 || weekday(strcat('2016-03-',d)) == 7    %        weekend = weekend + 1;    %        continue    %    end                % Call GetTrajs to get the flows of the neighbouring cells        aa = [];        for i = 1:numZones            dataneighbour = data(data(:,1) == neighbourcell(i),:);            [a, ~] = GetTrajs(dataneighbour,d);            aa = [aa a];        end         traj2 = [traj2; aa];                % Get information of the interested cell        data = data(data(:,1) == cell_id,:);        [a, b] = GetTrajs(data,d);        traj = [traj; a];        time = [time; b];            end    % Take out weekends (optional)    %numdays = numdays - weekend;    x_temporal = repmat(time/5+1,numZones+1,1); % Prediction only works on continuous time stamps (1,2,3,...) not (0,5,10,...)    y = [traj;traj2(:,1);traj2(:,2);traj2(:,3)];    x = [coordx coordy x_temporal];    x = Normalize(x);    xtrain = x(1:283*trainDays,:);    ytrain = y(1:283*trainDays);    for i = 1:numZones        xtrain = [xtrain; x(i*283*numdays+1:i*283*numdays+283*trainDays, :)];        ytrain = [ytrain; y(i*283*numdays+1:i*283*numdays+283*trainDays)];    end        meanfunc = {};    covfunc = {@covProd,{{@covMask,{[1 1 0],@covSEiso}},{@covMask,{[0 0 1],{'covProd',{'covPeriodic',{'covProd',{'covRQiso','covPeriodic'}}}}}}}};    likfunc = @likGauss;    hyp = struct('mean',[],'cov', [0 0 0 0 0 0 0 0 0 0 0], 'lik', -1);    hyp2 = minimize(hyp, @gp, -100, @infExact, meanfunc, covfunc, likfunc, xtrain, ytrain);    % Predict and Plot    plotdays = linspace(trainDays, numdays, numdays-trainDays); % the dates to predict    for i = 1:length(plotdays)        xtest = x(283*(plotdays(i)-1)+1:283*plotdays(i), :);        ytest = y(283*(plotdays(i)-1)+1:283*plotdays(i));        for j = 1:numZones            xtest = [xtest;x(283*(plotdays(i)-1)+j*283*numdays+1:283*plotdays(i)+j*283*numdays, :)];            ytest = [ytest;y(283*(plotdays(i)-1)+j*283*numdays+1:283*plotdays(i)+j*283*numdays, :)];        end        [mu, s2] = gp(hyp2, @infExact, meanfunc, covfunc, likfunc, xtrain, ytrain, xtest);        fig = figure;        plot(ytest(1:283),'b', 'LineWidth',2);        hold on;        plot(mu(1:283),'r');        legend('Actual Flow', 'Prediction');        hold off;        saveas(fig, strcat('03-',num2str(plotdays(i)),'-',num2str(cell_id),'-padded.png'));    endend