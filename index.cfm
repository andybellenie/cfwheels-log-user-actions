<h1>'Log User Actions' Plugin for CF Wheels</h1>
<h4>Version 0.3 BETA <br>
By Andy Bellenie</h4>
<p>
This plugin allows the automatic completion of user logging fields during create, update and delete actions.<br>
<br> 
To enable this plugin you need to include one or more of the following settings in config/settings.cfm <br>
&lt;cfset set(logUserOnCreateProperty=&quot;{created by column name}&quot;)&gt;<br>
&lt;cfset set(logUserOnUpdateProperty=&quot;{updated by column name}&quot;)&gt;<br>
&lt;cfset set(logUserOnDeleteProperty=&quot;{deleted by column name}&quot;)&gt;</p>
<p>NOTE: You must have soft deletion enabled to log delete events. For more information on soft deletion, please refer to the Wheels <a href="http://cfwheels.org/docs" target="_blank">documentation</a>. </p>
<p>The default user identifier to log is 'session.userId' which must exist for logging to work. If you wish to change this, also set the following:<br>
&lt;cfset set(userIdLocation=&quot;{user id variable (in any scope)} &quot;)&gt;</p>
<p>For questions, errors or suggestions please email <a href="mailto:andybellenie@gmail.com">andybellenie@gmail.com</a></p>
<p>&nbsp; </p>
