// Decompiled by Jad v1.5.8g. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.kpdus.com/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   FrameReceiver.java

package pk.aamir.stompj.internal;

import java.io.*;
import java.util.*;
import java.util.logging.Logger;

import pk.aamir.stompj.*;

// Referenced classes of package pk.aamir.stompj.internal:
//            MessageImpl, StompJSession, ErrorImpl

public class FrameReceiver extends Thread {
	private volatile boolean mRun = true;

	public FrameReceiver(StompJSession session, InputStream input, Map handlers) {
		this.session = session;
		this.input = input;
		messageHandlers = handlers;
		mRun = true;
	}

	public ErrorMessage processFirstResponse() throws IOException {
		String command = getLine();
		if (command.equals("CONNECTED")) {
			processCONNECTEDFrame();
			return null;
		}
		if (command.equals("ERROR")) {
			ErrorMessage em = processERRORFrame();
			return em;
		} else {
			return null;
		}
	}

	public void run() {
		mRun = true;
		do
			processInComingFrame();
		while (mRun);
	}

	private void processInComingFrame() {
		String command = getLine();
		if (command.equals("MESSAGE"))
			processMESSAGEFrame();
		else if (command.equals("ERROR"))
			processERRORFrame();
		else if (command.equals("RECEIPT"))
			getFrameBody(-1);
	}

	private String getLine() {
		ByteArrayOutputStream bos = new ByteArrayOutputStream();
		String line = "";
		try {
			do {
				byte b = (byte) input.read();
				if (b == 10) {
					break;
				} else if (b == -1) {
					mRun = false;
					break;
				}
				bos.write(b);
			} while (true);
			line = new String(bos.toByteArray(), "UTF-8");
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException(e);
		} catch (IOException e) {
			throw new StompJRuntimeException(e.getMessage(), e);
		}
		return line;
	}

	private void processMESSAGEFrame() {
		HashMap properties = getProperties();
		final MessageImpl msg = new MessageImpl();
		String cl = (String) properties.get("content-length");
		int contentLength = -1;
		if (cl != null) {
			contentLength = Integer.parseInt(cl);
			properties.remove("content-length");
		}
		String msgId = (String) properties.remove("message-id");
		msg.setMessageId(msgId);
		String destination = (String) properties.remove("destination");
		msg.setDestination(destination);
		msg.setProperties(properties);
		msg.setContent(getFrameBody(contentLength));
		session.sendAckIfNeeded(msg);
		for (Iterator iter = ((Set) messageHandlers.get(msg.getDestination()))
				.iterator(); iter.hasNext(); (new Thread() {

			public void run() {
				val$mh.onMessage(val$msg);
			}

			final FrameReceiver this$0;
			private final MessageHandler val$mh;
			private final MessageImpl val$msg;

			{
				this$0 = FrameReceiver.this;
				val$mh = mh;
				val$msg = msg;
			}
		}).start())
			mh = (MessageHandler) iter.next();

	}

	private ErrorMessage processERRORFrame() {
		HashMap properties = getProperties();
		ErrorImpl error = new ErrorImpl();
		String cl = (String) properties.get("content-length");
		int contentLength = -1;
		if (cl != null)
			contentLength = Integer.parseInt(cl);
		error.setMessage((String) properties.get("message"));
		error.setContent(getFrameBody(contentLength));
		session.getConnection().getErrorHandler().onError(error);
		return error;
	}

	private void processCONNECTEDFrame() throws IOException {
		HashMap prop = getProperties();
		sessionId = (String) prop.get("session");
		getFrameBody(-1);
	}

	private HashMap getProperties() {
		HashMap properties = new HashMap();
		do {
			String line = getLine();
			if (line.length() != 0) {
				String p[] = line.split(":", 2);
				if (p.length == 1)
					properties.put(p[0], "");
				if (p.length == 0)
					properties.put("", "");
				properties.put(p[0], p[1]);
			} else {
				return properties;
			}
		} while (true);
	}

	private byte[] getFrameBody(int bodyLength) {
		ByteArrayOutputStream bos;
		label0: {
			bos = new ByteArrayOutputStream();
			try {
				do {
					if (bodyLength == 0) {
						getFrameBody(-1);
						break label0;
					}
					byte b = (byte) input.read();
					if (b == 0 && bodyLength == -1)
						break label0;
					bos.write(b);
				} while (bodyLength != bos.size());
				getFrameBody(-1);
			} catch (IOException e) {
				throw new StompJRuntimeException(e.getMessage(), e);
			}
		}
		return bos.toByteArray();
	}

	private StompJSession session;
	private InputStream input;
	private String sessionId;
	private Map messageHandlers;
	private MessageHandler mh;
}
