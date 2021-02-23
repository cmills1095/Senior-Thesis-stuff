function dataSpacePlot(x,y,inModels,data)
hold on;
ensembleColor = [200 200 200]/255;

%Ensemble solution
for i=1:size(y,2)-1
    plot(x,y(:,i),'Color',ensembleColor);
end
i = size(y,2);
h = plot(x,y(:,i),'Color',ensembleColor,'DisplayName','Ensemble Members');

set(gcf,'Color','w');
for i = 1:size(inModels,2)
    plot(data.x,inModels{i}.y,'Color',inModels{i}.color,'LineStyle',...
        inModels{i}.lineStyle,'LineWidth',1.25,...
        'DisplayName',inModels{i}.displayName);
end
h1 = plot(x,mean(y,2),'b--','LineWidth',1,'DisplayName','DS Mean');
h2 = plot(data.x,data.y,'.','Color',inModels{1}.color,'MarkerSize',10.0,...
    'DisplayName','Data + noise');
lgd = legend([h1,h2,h],'Location','northwest');
lgd.FontSize = 8;
set(gca,'FontSize',12,'Color','w','XScale','log','YScale','log','Box','on');
xlabel('Array Spacing (m)'); ylabel('Apparent Resistivity (\Omega-m)')
text(0.95,0.95,'B','units','normalized','FontSize',14)
end