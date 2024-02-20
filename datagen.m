TEXTURES_DIR= "dtd/images/all";
CARDS_DIR = "deck";
OUT_DIR = "dataset";

CARDS_ENTRIES = dir(CARDS_DIR + "/*.png");
TEXTURES_ENTRIES = dir(TEXTURES_DIR + "/*.jpg");

N_CARDS = length(CARDS_ENTRIES);
N_TEXTURES = length(TEXTURES_ENTRIES);

MAX_S = 640;

N_SAMPLES = 1000;

CARD_MASK = imread("cardmask.png");
CARD_MASK = CARD_MASK(:, :, 1) > 0;

gt = [];

for i=1:N_SAMPLES	
	% Pick a random texture
	tid = randi(N_TEXTURES);	
	tex = imread(TEXTURES_DIR + "/" + ...
				 TEXTURES_ENTRIES(tid).name);
	[th, tw, tc] = size(tex);

	min_s = min(size(tex, 1, 2));

	polymasks = zeros([th, tw, 1]) > 0;
	classes = string([]);

	n_cards = randi([2, 6]);
	scale = (0.8 + rand()) * min_s / MAX_S;

	sample = tex;
	for j=1:n_cards
		cid = randi(N_CARDS);
		[card, ~, alpha] = imread(CARDS_DIR + "/" + ...
								  CARDS_ENTRIES(cid).name);
		alpha(alpha < 0.9) = 0;
		[ch, cw, cc] = size(card);
		card = imresize(card, round([ch, cw] * scale));
		alpha = imresize(CARD_MASK, round([ch, cw] * scale));
		[rch, rcw, ~] = size(card);

		hsv = rgb2hsv(card);
		h = hsv(:, :, 1) - 0.005 + rand() * 0.01;
		s = hsv(:, :, 2) - 0.2 + rand() * 0.4;
		v = hsv(:, :, 3) - 0.2 + rand() * 0.4;
		s(s < 0) = 0;
		v(v < 0) = 0;
		h(h < 0) = 0;
		card = uint8(hsv2rgb(cat(3, h, s, v * 255)) .* alpha);

		overlaps = true;
		retries = 0;
		while overlaps
			cx = round(tw * 0.2 + (tw - 1) * rand() * 0.8);
			cy = round(th * 0.2 + (th - 1) * rand() * 0.8);

			angle = randi([0, 179]);
			
			rot_card = imrotate(card, angle);
			rot_alpha = uint8(imrotate(alpha, angle));

			mask = impaste(rot_alpha, uint8(zeros([th, tw])), rot_alpha, [cx, cy]);
			mask = mask > 0;
			
			overlaps = true;
			visible_area = (mask - sum(polymasks, 3)) > 0;
			if nnz(visible_area) / (rch * rcw)  > 0.6
				sample = impaste(rot_card, sample, rot_alpha, [cx, cy]);
				polymasks = cat(3, polymasks, mask);
				
				splt = split(CARDS_ENTRIES(cid).name, '.');
				classes = [classes, splt(1)];
				overlaps = false;
				retries = 0;
			else
				retries = retries + 1;
				if retries > 3
					break;
				end
			end
		end
	end

	sample = imfilter(sample, fspecial('gaussian', 3, 0.5));
	if rand() < 0.5
		sample = imfilter(sample, ...
			fspecial('gaussian', 1 + round(rand() * 6), 0.5 + rand()));
	else
		sample = imsharpen(sample, 'amount', rand());
	end

	sample = imnoise(sample, 'gaussian', 0, 0.001);

	polymasks(:, :, 1) = [];
	n_polymasks = size(polymasks, 3);

	annots = [];
	% Generate segmentation polygons
	for j=1:n_polymasks
		mask = polymasks(:, :, j);
		if j < n_polymasks
			mask = mask - sum(polymasks(:, :, j+1:n_polymasks), 3) > 0;
		end
	
		conn_comps = bwlabel(mask);
		n_comps = max(unique(conn_comps));
		
		if n_comps > 1
			areas = zeros(1, n_comps);
			for k=1:n_comps
				areas(k) = nnz(conn_comps == k);
			end

			[~, max_idx] = max(areas);

			mask = conn_comps == max_idx;
		end

		% Polygonal approx
		borders = cell2mat(bwboundaries(mask, 'CoordinateOrder', 'xy'));
		poly = reducepoly(borders, 0.009);

		bbox = regionprops(mask, 'BoundingBox').BoundingBox;

		annot.polygon = poly;
		annot.bbox = bbox;
		annot.class = classes(j);
	
		annots = [annots, annot];
	end

	image_filename = num2str(i, "%05d") + ".jpg";

	imwrite(sample, OUT_DIR + "/" + image_filename);
	disp("Generated " +  image_filename);
		
	gt_entry.image_path = image_filename;
	gt_entry.annotations = annots;	

	gt = [gt, gt_entry];

end


out_json = fopen("gt.json", "w");
fprintf(out_json, jsonencode(gt));
