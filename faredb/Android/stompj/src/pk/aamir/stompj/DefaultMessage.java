// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   DefaultMessage.java

package pk.aamir.stompj;

import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.Set;

// Referenced classes of package pk.aamir.stompj:
//            Message

public class DefaultMessage implements Message {

	public DefaultMessage() {
		properties = new HashMap();
	}

	public DefaultMessage(String content) {
		this();
		setContent(content);
	}

	public DefaultMessage(byte content[]) {
		this();
		setContent(content);
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

	public void setContent(String content) {
		try {
			this.content = content.getBytes("UTF-8");
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException(e);
		}
	}

	public String getDestination() {
		return destination;
	}

	public String getMessageId() {
		return messageId;
	}

	public String getProperty(String key) {
		return (String) properties.get(key);
	}

	public String[] getPropertyNames() {
		return (String[]) properties.keySet().toArray(new String[0]);
	}

	public void setProperty(String name, String value) {
		properties.put(name, value);
	}

	private String messageId;
	private String destination;
	private HashMap properties;
	private byte content[];
}
