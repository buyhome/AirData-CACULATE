package irdc.EX08_01;


/*必需引用apache.http相关类别来建立HTTP联机*/
import org.apache.http.HttpResponse; 
import org.apache.http.NameValuePair; 
import org.apache.http.client.ClientProtocolException; 
import org.apache.http.client.entity.UrlEncodedFormEntity; 
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost; 
import org.apache.http.impl.client.DefaultHttpClient; 
import org.apache.http.message.BasicNameValuePair; 
import org.apache.http.protocol.HTTP; 
import org.apache.http.util.EntityUtils; 


/*必需引用java.io 与java.util相关类来读写文件*/
import java.io.IOException; 
import java.util.ArrayList; 
import java.util.List; 
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import android.app.Activity; 
import android.os.Bundle; 
import android.view.View; 
import android.widget.Button; 
import android.widget.TextView; 

/*ActiveMQ*/
import pk.aamir.stompj.*;
import pk.aamir.stompj.internal.*;

public class EX08_01 extends Activity 
{ 
  /*声明一个Button对象,与一个TextView对象*/
  private Button mButton1;
  private Button mButton2;
  private TextView mTextView1; 
   
  /** Called when the activity is first created. */ 
  @Override 
  public void onCreate(Bundle savedInstanceState) 
  { 
    super.onCreate(savedInstanceState); 
    setContentView(R.layout.main); 
     
    /*透过findViewById建构子建立TextView与Button对象*/ 
    mButton1 =(Button) findViewById(R.id.myButton1);
    mButton2 =(Button) findViewById(R.id.myButton2);
    mTextView1 = (TextView) findViewById(R.id.myTextView1); 
    
    /*设定OnClickListener来聆听OnClick事件*/ 
    mButton2.setOnClickListener(new Button.OnClickListener() 
    { 
      @Override 
      public void onClick(View v) 
      { 
        // TODO Auto-generated method stub 
        /*声明网址字符串*/
        Connection con = new Connection("192.168.13.111", 61612, "admin", "admin");
        try
        {
          con.connect();

          DefaultMessage msg = new DefaultMessage();
          msg.setProperty("type", "text/plain");
          msg.setContent("Another test message!");
          con.send(msg, "/queue/ifl_ticket");

          con.disconnect();
          
        } catch (StompJException e)
        {
          // TODO Auto-generated catch block
          mTextView1.setText(e.getMessage().toString());
          e.printStackTrace();
        }
      }
    }); 
    
    mButton1.setOnClickListener(new Button.OnClickListener() 
    { 
      @Override 
      public void onClick(View v) 
      { 
        // TODO Auto-generated method stub 
        /*声明网址字符串*/
        Connection con = new Connection("192.168.13.111", 61612, "admin", "admin");
        try
        {
          con.connect();

          con.subscribe("/queue/ifl_ticket", true);
          con.addMessageHandler("/queue/ifl_ticket", new MessageHandler() {
            public void onMessage(Message msg) {
              //System.out.println(msg.getContentAsString());
              String strResult = msg.getContentAsString();
              strResult = eregi_replace("(\r\n|\r|\n|\n\r)","",strResult);
              mTextView1.setText(strResult);
              
              /*声明网址字符串*/
              String uriAPI = "http://10.124.20.136/data-base";
              /*建立HTTP Post联机*/
              HttpPost httpRequest = new HttpPost(uriAPI); 
              /*
               * Post运作传送变量必须用NameValuePair[]数组储存
               * 2013/01/19 19:27:48 [debug] 18229#0: *14 http header: "Content-Type: application/x-www-form-urlencoded"
               * 2013/01/19 19:27:48 [debug] 18229#0: *14 http header: "Host: labs.rhomobi.com"
               * 2013/01/19 19:27:48 [debug] 18229#0: *14 http header: "Connection: Keep-Alive"
               * 2013/01/19 19:27:48 [debug] 18229#0: *14 http header: "User-Agent: Apache-HttpClient/UNAVAILABLE (java 1.4)"
              */
              List <NameValuePair> params = new ArrayList <NameValuePair>(); 
              //params.add(new BasicNameValuePair("str", "I am Post String"));
              params.add(new BasicNameValuePair("body", strResult));
              try 
              { 
                /*发出HTTP request*/
                httpRequest.setEntity(new UrlEncodedFormEntity(params, HTTP.UTF_8)); 
                /*取得HTTP response*/
                HttpResponse httpResponse = new DefaultHttpClient().execute(httpRequest); 
                /*若状态码为200 ok*/
                if(httpResponse.getStatusLine().getStatusCode() == 200)  
                { 
                  /*取出响应字符串*/
                  String strResultPost = EntityUtils.toString(httpResponse.getEntity());
                  mTextView1.setText(strResultPost); 
                } 
                else 
                { 
                  mTextView1.setText("Error Response: "+httpResponse.getStatusLine().toString()); 
                } 
              } 
              catch (ClientProtocolException e) 
              {  
                mTextView1.setText(e.getMessage().toString()); 
                e.printStackTrace(); 
              } 
              catch (IOException e) 
              {  
                mTextView1.setText(e.getMessage().toString()); 
                e.printStackTrace(); 
              } 
              catch (Exception e) 
              {  
                mTextView1.setText(e.getMessage().toString()); 
                e.printStackTrace();  
              }  
              
            }
          });
          
          //con.disconnect();
          
        } catch (StompJException e)
        {
          // TODO Auto-generated catch block
          mTextView1.setText(e.getMessage().toString());
          e.printStackTrace();
        }
      }
    }); 
  }
    /* 自定义字符串取代函数 */
    public String eregi_replace(String strFrom, String strTo, String strTarget)
    {
      String strPattern = "(?i)"+strFrom;
      Pattern p = Pattern.compile(strPattern);
      Matcher m = p.matcher(strTarget);
      if(m.find())
      {
        return strTarget.replaceAll(strFrom, strTo);
      }
      else
      {
        return strTarget;
      }
    }
    
    
}
