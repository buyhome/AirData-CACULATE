// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   ErrorHandler.java

package pk.aamir.stompj;

// Referenced classes of package pk.aamir.stompj:
//            ErrorMessage

public interface ErrorHandler {

	public abstract void onError(ErrorMessage errormessage);
}
