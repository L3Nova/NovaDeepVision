function res = impaste(source, dest, mask, center)
	% size of img to be pasted	
	[sh, sw, sc] = size(source);

	% size of img where pasting is occurring
	[dh, dw, dc] = size(dest);
	
	sh2 = ceil(sh / 2);
	sw2 = ceil(sw / 2);

	% coordinates of the point where the paste is going
	% to be centered in
	cx = center(1);
	cy = center(2);
	
	% making sure image is not pasted outside destination image
	% add padding to destination img
	% padding size is equal to half the size of img to be pasted
	padded_dest = padarray(dest, ceil([sh, sw] / 2), 0);

	% getting a crop of where the img is going to be pasted
	dest_crop = imcrop(padded_dest, [cx, cy, sw-1, sh-1]);
	
	% update destination crop pixels with img to be pasted
	padded_dest(cy:cy+sh-1, cx:cx+sw-1, :) = dest_crop .* uint8(~mask) + source;

	% cropping back to correct size
	res = imcrop(padded_dest, [sw2+1, sh2+1, dw-1, dh-1]);

end
