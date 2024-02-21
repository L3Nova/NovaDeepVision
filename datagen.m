% textures dataset directory
TEXTURES_DIR= "dtd";

% single cards crops directory
CARDS_DIR = "deck";

% destination for generated images
OUT_DIR = "dataset";

% get list of all cards in card crops folder
CARDS_ENTRIES = dir(CARDS_DIR + "/*.png");

% get list of all texture files in textures dataset
TEXTURES_ENTRIES = dir(TEXTURES_DIR + "/*.jpg");

% get total number of cards and textures
N_CARDS = length(CARDS_ENTRIES);
N_TEXTURES = length(TEXTURES_ENTRIES);

% max image size in texture dataset
MAX_S = 640;

% loading fixed mask for all card crops
CARD_MASK = imread("cardmask.png");
CARD_MASK = CARD_MASK(:, :, 1) > 0;

% how many imgs to be generated
N_SAMPLES = 5000;

% annotations
gt = [];

% generate images
for i=1:N_SAMPLES	
	% Pick a random texture
	tid = randi(N_TEXTURES);	
	tex = imread(TEXTURES_DIR + "/" + ...
				 TEXTURES_ENTRIES(tid).name);
	
	[th, tw, tc] = size(tex);

	% minimum of width and height of texture img
	min_s = min(size(tex, 1, 2));

	% array that contains cards masks
	polymasks = zeros([th, tw, 1]) > 0;
	
	% array that contains classifications
	classes = string([]);

	% each img has min 2 and max 6 cards
	n_cards = randi([2, 6]);

	% randomly generate scale card relative to ratio of texture img
	scale = (0.8 + rand()) * min_s / MAX_S;

	% sample will be the final generated img
	sample = tex;

	for j=1:n_cards
		% Pick a random card to paste onto texture
		cid = randi(N_CARDS);
		[card, ~, alpha] = imread(CARDS_DIR + "/" + ...
								  CARDS_ENTRIES(cid).name);
		
		% mask of the card
		alpha(alpha < 0.9) = 0;

		[ch, cw, cc] = size(card);
		
		% resizing card to randomly generated scale
		card = imresize(card, round([ch, cw] * scale));
		% resizing card mask to the same size
		alpha = imresize(CARD_MASK, round([ch, cw] * scale));
		
		[rch, rcw, ~] = size(card);

		% data augmentation on hsv color space
		% randomly shift intensity, saturation and hue of the card
		hsv = rgb2hsv(card);
		h = hsv(:, :, 1) - 0.005 + rand() * 0.01;
		s = hsv(:, :, 2) - 0.2 + rand() * 0.4;
		v = hsv(:, :, 3) - 0.2 + rand() * 0.4;
		% make sure values are non negative
		s(s < 0) = 0;
		v(v < 0) = 0;
		h(h < 0) = 0;

		% going back to rgb and applying card mask
		card = uint8(hsv2rgb(cat(3, h, s, v * 255)) .* alpha);

		% card is now augmented crop

		% handling overlapping cards
		overlaps = true;
		retries = 0;

		while overlaps
			% generate random point where to paste card inside texture img
			cx = round(tw * 0.2 + (tw - 1) * rand() * 0.8);
			cy = round(th * 0.2 + (th - 1) * rand() * 0.8);

			% geberate random rotation angle for the card to be pasten in
			angle = randi([0, 179]);
			
			% rotating card by the generated angle
			rot_card = imrotate(card, angle);
			% rotating card mask by the same angle
			rot_alpha = uint8(imrotate(alpha, angle));

			% placing mask of the card onto img of the masks of all
			% previously pasted cards in current img
			mask = impaste(rot_alpha, uint8(zeros([th, tw])), rot_alpha, [cx, cy]);
			mask = mask > 0;
			
			overlaps = true;

			% Check for a max overlapping thresholding between cards
			% in the image, to avoid them being fully overlapped or
			% covering every symbols inside it

			% subtract every other other card from current
			visible_area = (mask - sum(polymasks, 3)) > 0;
			
			% area of visible / area of whole card
			if nnz(visible_area) / (rch * rcw)  > 0.6
				% pasting actual card onto img being built
				sample = impaste(rot_card, sample, rot_alpha, [cx, cy]);
				
				% adding card segmentation to the list of segmentations
				% in the img 
				polymasks = cat(3, polymasks, mask);
				
				% 1-red.png will be class 1-red
				splt = split(CARDS_ENTRIES(cid).name, '.');
				classes = [classes, splt(1)];

				overlaps = false;
				retries = 0;
			else
				% if card is not visible at least for 60% of its area
				% try 3 times max
				retries = retries + 1;
				if retries > 3
					break;
				end
			end
		end
	end

	% apply preliminary smoothing to img
	sample = imfilter(sample, fspecial('gaussian', 3, 0.5));

	% randomly sharpen or blur img
	if rand() < 0.5
		sample = imfilter(sample, ...
			fspecial('gaussian', 1 + round(rand() * 6), 0.5 + rand()));
	else
		sample = imsharpen(sample, 'amount', rand());
	end

	% add gaussian noise
	sample = imnoise(sample, 'gaussian', 0, 0.001);

	polymasks(:, :, 1) = [];
	n_polymasks = size(polymasks, 3);

	annots = {};
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
	
		annots = cat(1, annots, annot);
	end

	image_filename = num2str(i, "%05d") + ".jpg";

	% save generated img with name an incremental id
	imwrite(sample, OUT_DIR + "/" + image_filename);
	disp("Generated " +  image_filename);
	
	% build annotations json
	gt_entry.image_path = image_filename;
	gt_entry.annotations = annots;	

	gt = [gt, gt_entry];

end

% print out all N_SAMPLES annotations to json file
out_json = fopen("annotations.json", "w");
fprintf(out_json, jsonencode(gt));
