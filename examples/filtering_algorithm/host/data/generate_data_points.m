%**********************************************************************
% Felix Winterstein, Imperial College London, 2016
%
% File: generate_data_points
%
% Revision 1.01
% Additional Comments: distributed under an Apache-2.0 license, see LICENSE
%
%**********************************************************************

function generate_data_points

clear;
clc;


%% config
N=2^20;
D=3;
K=128;
Knew =K;
std_dev = 0.10;
M=1;

fractional_bits = 10;
gbl_seed_offset = 0;

for file_idx=1:M

    %% generate data points
    %rng(16221+gbl_seed_offset);
    rand('seed',16221+gbl_seed_offset+file_idx);
    centres = 5*(rand(K,D)-0.5);

    points=zeros(N,D);

    for I=1:K
        for II=1:D
            %rng(4567+gbl_seed_offset+10*I+II);
            randn('seed',4567+gbl_seed_offset+10*I+II+file_idx);
            points((I-1)*N/K+1:N/K*I,II) = centres(I,II)+std_dev*randn(N/K,1);               
        end
    end

    tmp=max([abs(min(points(:,1))),abs(max(points(:,1))),abs(min(points(:,2))),abs(max(points(:,2)))]);

    points=points/tmp;
    centres = centres/tmp;

    points=round(points*2^fractional_bits);
    centres=round(centres*2^fractional_bits);
    
    %% save data points to file
    tmp_points=reshape(points,D*N,1); % append 2nd dim after 1st dim

    fid=fopen(['./data_points','_N',num2str(N),'_K',num2str(K),'_D',num2str(D),'_s',num2str(std_dev,'%.2f'),'.mat'],'w');
    for I=1:D*N
       fprintf(fid,'%d\n',tmp_points(I));
    end
    fclose(fid);        

    %% generate new random centres (pick K data points randomly) and save to file
    new_centres = zeros(Knew,D);

    %rng(4567+gbl_seed_offset+10000+II);
    rand('seed', 4567+gbl_seed_offset+10000+file_idx);
    new_centres_idx= round(rand(N,1)*N);
    new_centres_idx = new_centres_idx(1:Knew);
    %new_centres = points(new_centres_idx,:);

    %tmp_new_centres=reshape(new_centres,D*Knew,1); % append 2nd dim after 1st dim

    fid=fopen(['./initial_centers','_N',num2str(N),'_K',num2str(Knew),'_D',num2str(D),'_s',num2str(std_dev,'%.2f'),'_',num2str(file_idx),'.mat'],'w');

    for I=1:Knew
       fprintf(fid,'%d\n',new_centres_idx(I));
    end
    fclose(fid);
end 




end
