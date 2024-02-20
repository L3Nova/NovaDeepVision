function res = impaste(source, dest, mask, center)
	
	[sh, sw, sc] = size(source);
	[dh, dw, dc] = size(dest);
	
	sh2 = ceil(sh / 2);
	sw2 = ceil(sw / 2);

	cx = center(1);
	cy = center(2);
		
	padded_dest = padarray(dest, ceil([sh, sw] / 2), 0);
	dest_crop = imcrop(padded_dest, [cx, cy, sw-1, sh-1]);
	
	padded_dest(cy:cy+sh-1, cx:cx+sw-1, :) = dest_crop .* uint8(~mask) + source;

	res = imcrop(padded_dest, [sw2+1, sh2+1, dw-1, dh-1]);

end
