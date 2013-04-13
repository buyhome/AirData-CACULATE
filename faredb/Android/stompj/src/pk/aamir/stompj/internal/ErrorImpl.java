// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   ErrorImpl.java

package pk.aamir.stompj.internal;

import java.io.UnsupportedEncodingException;
import pk.aamir.stompj.ErrorMessage;

public class ErrorImpl implements ErrorMessage {

	public ErrorImpl() {
	}

	public byte[] getContentAsBytes() {
		return content;
	}

	public String getContentAsString() {
		try {
			return new String(content, "UTF-8");
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException(e);
		}
	}

	public void setContent(byte content[]) {
		this.content = content;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String msg) {
		message = msg;
	}

	private String message;
	private byte content[];
}
