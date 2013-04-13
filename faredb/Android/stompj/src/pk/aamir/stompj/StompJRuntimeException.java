// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   StompJRuntimeException.java

package pk.aamir.stompj;

public class StompJRuntimeException extends RuntimeException {

	public StompJRuntimeException(String message) {
		super(message);
	}

	public StompJRuntimeException(String message, Throwable cause) {
		super(message, cause);
	}
}
