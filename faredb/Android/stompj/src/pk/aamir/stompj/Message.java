// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   Message.java

package pk.aamir.stompj;

public interface Message {

	public abstract String getMessageId();

	public abstract String getDestination();

	public abstract String getProperty(String s);

	public abstract String[] getPropertyNames();

	public abstract String getContentAsString();

	public abstract byte[] getContentAsBytes();
}
