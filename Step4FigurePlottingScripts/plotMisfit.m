function plotMisfit(inModels,results)
histogram(results.ensembleMisfits,100,'EdgeAlpha',0);
hold on;
yy=get(gca,'YLim');
for iPlot = 1:size(inModels,2)
    plot(inModels{iPlot}.misfit*[1 1],yy,'LineStyle',...
        inModels{iPlot}.lineStyle,'Color',inModels{iPlot}.color,...
        'LineWidth',1.0);
end
set(gca,'FontSize',10);
xlabel('Misfit (\Omega-m)');


%text(0.9,0.8,'A','units','normalized','FontSize',14);

end
