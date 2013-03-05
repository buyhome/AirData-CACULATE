		local area = "777x888"
		local resw = "730x400"


        local lenparameter = string.len(area);
        i,j = string.find(area, "x");
        local wpara = tonumber(string.sub(area, 1, i-1))
        local hpara = tonumber(string.sub(area, i+1, lenparameter))

        local lensource = string.len(resw);
        y,z = string.find(resw, "x");
        local wresw = tonumber(string.sub(resw, 1, y-1))
        local hresw = tonumber(string.sub(resw, y+1, lensource))



		print(wpara,hpara)
		print(wresw,hresw)

        if ( wpara > wresw and hpara > hresw ) then

                print("ok")

        else
				print("not")
		end



		local lenparameter = string.len(area);
        i,j = string.find(area, "x");
        local wpara = tonumber(string.sub(area, 1, i-1))
        local hpara = tonumber(string.sub(area, i+1, lenparameter))

        local lensource = string.len(resw);
        y,z = string.find(resw, "x");
        local wresw = tonumber(string.sub(resw, 1, y-1))
        local hresw = tonumber(string.sub(resw, y+1, lensource))

--0172012110500210a8789c05524415941e2f32899cc37b.jpg=373x373.jpg


		local conUri = "0172012110500210a8789c05524415941e2f32899cc37b.jpg=373x373.jpg"
		local index = string.find(conUri, "([0-9]+)x([0-9]+)");
		print("-------------")
		print(index)
		print("-------------")
        local originalUri = string.sub(conUri, 0, index-2);
		print(originalUri)
		--local area = string.sub(conUri, index, -1)
        local area = string.sub(conUri, index);
		print(area)
        index = string.find(area, "([.])");
		area = string.sub(area, 0, index-1);

		print(area);
