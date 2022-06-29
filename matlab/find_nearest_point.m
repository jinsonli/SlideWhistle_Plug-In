function [index, value] = find_nearest_point(array, point)

distance = array - point;
% distance = sqrt((array - point).* (array - point));
[val, id] = min(abs(distance));
index = id;
value = distance(id);

