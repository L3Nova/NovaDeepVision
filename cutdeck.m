[im, ~, alpha] = imread('deck.png');

cards_labels = bwlabel(alpha);

for i=1:max(unique(cards_labels))
	card_mask = cards_labels == i;
	card = im .* uint8(card_mask);

	bbox = uint16(regionprops(card_mask).BoundingBox);

	card_crop = imcrop(card, [bbox(1), bbox(2), bbox(3)-1, bbox(4)-1);
	alpha_crop = imcrop(alpha, [bbox(1), bbox(2), bbox(3)-1, bbox(4)-1);
	
	imshow(card_crop);

	s = input('filename', 's');
	if s == "n"
		continue;
	else
		imwrite(card_crop, s + ".png", 'Alpha', alpha_crop)
	end
end
