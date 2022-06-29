load('scan');

figure(1); hold on;
plot(scan.pwm_array, scan.freq_array(:, 1));      

scan.servo_pwm_array   = [];
scan.servo_pih_array   = [];
error_cent_array = [];
[pitch, freq] = get_frequency_pitch_table();
for i = 2 : length(freq) - 1
    pih = pitch(i);
    ref_lower_frequency = freq(i - 1);
    ref_center_frequency = freq(i);
    [index, distance] = find_nearest_point(scan.freq_array(:, 1), ref_center_frequency);
    freq_range  = ref_lower_frequency - ref_center_frequency;
    err_cent    = min(abs(distance / freq_range) * 100, 100);
    
    pwm = scan.pwm_array(index);
    if (err_cent < 50)
        scan.servo_pwm_array   = [scan.servo_pwm_array, pwm];
        scan.servo_pih_array   = [scan.servo_pih_array, pih];
    end
    error_cent_array = [error_cent_array err_cent];
end

fid = fopen('pitch_table', 'w');

id = 1;

fprintf(fid, '#ifndef H_WHISTLE%d_CALI_H\n', id);
fprintf(fid, '#define H_WHISTLE%d_CALI_H\n\n', id);
fprintf(fid, '#define VALI_NUM%d 	(%d)\n\n', id, length(scan.servo_pih_array));
fprintf(fid, 'const int32_t whistle%d_param[VALI_NUM%d][4] = \n{\n', id, id);

for i = 1 : length(scan.servo_pih_array)    
    pih = scan.servo_pih_array(i);
    pwm = scan.servo_pwm_array(i);
    low  = 30;
    high = 50;
    fprintf(fid, '{%d, %d, %d, %d},\n',pih, pwm, low, high);    
end

fprintf(fid, '\n};\n\n');
fprintf(fid, '#endif //H_WHISTLE%d_CALI_H\n', id);
fclose(fid);
 
