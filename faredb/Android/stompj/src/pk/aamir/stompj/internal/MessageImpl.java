// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   MessageImpl.java

package pk.aamir.stompj.internal;

import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.Set;
import pk.aamir.stompj.Message;

public class MessageImpl implements Message {

	public MessageImpl() {
		properties = new HashMap();
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

	public String getDestination() {
		return destination;
	}

	public void setDestination(String destination) {
		this.destination = destination;
	}

	public String getMessageId() {
		return messageId;
	}

	public void setMessageId(String id) {
		messageId = id;
	}

	public String getProperty(String key) {
		return (String) properties.get(key);
	}

	public String[] getPropertyNames() {
		return (String[]) properties.keySet().toArray(new String[0]);
	}

	public void setProperties(HashMap properties) {
		this.properties = properties;
	}

	private String messageId;
	private String destination;
	private HashMap properties;
	private byte content[];
}
