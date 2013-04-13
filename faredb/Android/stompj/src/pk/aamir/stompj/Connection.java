// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   Connection.java

package pk.aamir.stompj;

import java.io.UnsupportedEncodingException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;
import pk.aamir.stompj.internal.MessageImpl;
import pk.aamir.stompj.internal.StompJSession;

// Referenced classes of package pk.aamir.stompj:
//            StompJException, MessageHandler, ErrorHandler, ErrorMessage, 
//            Message

public class Connection {

	public Connection() {
		this("localhost", 61613);
	}

	public Connection(String host, int port) {
		this(host, port, "", "");
	}

	public Connection(String host, int port, String userid, String password) {
		messageHandlers = new ConcurrentHashMap();
		session = new StompJSession(host, port, userid, password, this,
				messageHandlers);
	}

	public ErrorMessage connect() throws StompJException {
		return session.connect();
	}

	public void disconnect() {
		session.disconnect();
	}

	public boolean isConnected() {
		return session.isConnected();
	}

	public void subscribe(String destination, boolean autoAck) {
		session.subscribe(destination, autoAck);
	}

	public void unsubscribe(String destination) {
		session.unsubscribe(destination);
	}

	public void send(Message msg, String destination) {
		session.send(msg, destination);
	}

	public void send(String msg, String destination) {
		MessageImpl m = new MessageImpl();
		try {
			m.setContent(msg.getBytes("UTF-8"));
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException(e);
		}
		send(((Message) (m)), destination);
	}

	public void addMessageHandler(String destination, MessageHandler handler) {
		CopyOnWriteArraySet set = new CopyOnWriteArraySet();
		messageHandlers.putIfAbsent(destination, set);
		((CopyOnWriteArraySet) messageHandlers.get(destination)).add(handler);
	}

	public MessageHandler[] getMessageHandlers(String destination) {
		return (MessageHandler[]) ((CopyOnWriteArraySet) messageHandlers
				.get(destination)).toArray(new MessageHandler[0]);
	}

	public void removeMessageHandlers(String destination) {
		messageHandlers.remove("destination");
	}

	public ErrorHandler getErrorHandler() {
		return errorHandler;
	}

	public void setErrorHandler(ErrorHandler handler) {
		errorHandler = handler;
	}

	private StompJSession session;
	private ConcurrentHashMap messageHandlers;
	private ErrorHandler errorHandler;
}
