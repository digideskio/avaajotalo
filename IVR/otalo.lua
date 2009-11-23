#!/usr/local/bin/lua


-- INCLUDES

require "luasql.mysql";


-- GLOBALS

env = assert (luasql.mysql());
con = assert (env:connect("otalo","otalo","otalo","localhost"));

logfile = io.open("/Library/WebServer/Documents/AO/ao.log", "a");
script_name = "otalo.lua";
basedir = "/usr/local/freeswitch";
bsd = basedir .. "/sounds/en/us/callie/";
aosd = basedir .. "/scripts/AO/sounds/eng/";
sd = basedir .. "/storage/otalo/";
sessid = os.time();
digits = "";
currfile = "";
arg = {};

session:setVariable("playback_terminators", "#");
session:setHangupHook("hangup");
session:setInputCallback("my_cb", "arg");


-- FUNCTIONS

-----------
-- rows 
-----------

function rows (sql_statement)
  local cursor = assert (con:execute (sql_statement));
  freeswitch.consoleLog("info", script_name .. " : " .. sql_statement .. "\n")
  return function ()
	    row = {};
	    result = cursor:fetch(row);
	    if (result == nil) then
	       cursor:close();
	       return nil;
	    end;
	    return row;
	 end
end


-----------
-- hangup 
-----------

function hangup()
   -- cleanup
   con:close();
   env:close();
   logfile:flush();
   logfile:close();
   
   -- hangup
   session:hangup();
end


-----------
-- my_cb
-----------

function my_cb(s, type, obj, arg)
   freeswitch.console_log("info", "\narg: [" .. arg[2] .. "]\n")

   if (type == "dtmf") then
      
      logfile:write(sessid, "\t", session:getVariable("caller_id_number"), "\t", os.time(), "\t", currfile, "\t", "dtmf", "\t", obj['digit'], "\n"); 
      freeswitch.console_log("info", "\ndigit: [" .. obj['digit'] .. "]\nduration: [" .. obj['duration'] .. "]\n");

      if (obj['digit'] == "2") then
	 return "pause";
      end

      if (obj['digit'] == "3" or obj['digit'] == "#" or obj['digit'] == "0") then
	 digits = obj['digit'];
         return "break";
      end

      if (obj['digit'] == "4") then
	 return "seek:-500";
      end

      if (obj['digit'] == "5") then
	 --session:speak("start over");
         return "seek:0";
      end

      if (obj['digit'] == "6") then
	 --session:speak("seek forward");
         return "seek:+500";
      end
      
      if (obj['digit'] == "7") then
	 read(aosd .. "okinstructions.wav", 500);
	 read(aosd .. "instructions.wav", 500);
	 if (digits ~= "0") then
	    use()
	    read(aosd .. "backtomessage.wav", 1000);
	 end
	 if (digits == "0") then
	    return "break";
	 end
	 use();
	 return;
      end

      if (obj['digit'] == "8") then
	 read(aosd .. "okrecord.wav", 500);
	 recordmessage(arg[1], arg[2], arg[3], arg[4], arg[5]);
	 session:sleep(500);
	 if (digits ~= "0") then
	    use();
	    read(aosd .. "backtomessage.wav", 1000);
	 end
	 if (digits == "0") then
	    return "break";
	 end
	 use();
	 return;
      end

      if (obj['digit'] == "*") then
         --session:speak("stop");
         return "stop";
      end
   else
      freeswitch.console_log("info", obj:serialize("xml"));
   end
end


-----------
-- read
-----------

function read(file, delay)
   if (digits == "") then
      digits = session:read(1, 1, file, delay, "#");
      if (digits ~= "") then
	 logfile:write(sessid, "\t", session:getVariable("caller_id_number"), "\t", os.time(), "\t", file, "\t", "dtmf", "\t", digits, "\n"); 
      end
   end
end


----------
-- use
----------

function use()
   d = digits;
   digits = "";
   return d;
end


-----------
-- choosetag
-----------

function choosetag ()
   tagids = {};
   tagnames = {};
   
   read(aosd .. "welcome.wav", 2000);

   i = 0;
   for row in rows ("SELECT id, name_file FROM tag ORDER BY id ASC") do
      i = i + 1;
      tagids[i] = row[1];
      tagnames[i] = row[2];
      read(aosd .. "listento.wav", 500);
      read(aosd .. tagnames[i], 500);
      read(bsd .. "voicemail/8000/vm-press.wav", 500);
      read(bsd .. "digits/8000/" .. i .. ".wav", 2000);
   end
   
   d = use();

   if (d == "") then
      d = 1;
   else
      d = tonumber(d);
   end;

   if (d > 0 and d < i) then
      freeswitch.consoleLog("info", script_name .. " : Selected Tag : " .. tagnames[d] .. "\n");
      return tagids[d];
   else
      freeswitch.consoleLog("info", script_name .. " : No such tag number : " .. d .. "\n");
      session:sleep(500);
      read(aosd .. "notag.wav", 500);
      use();
      return 0;
   end
end


-----------
-- playmessage
-----------

function playmessage (msg)
   currfile = sd .. msg[2];
   logfile:write(sessid, "\t", session:getVariable("caller_id_number"), "\t", os.time(), "\t", currfile, "\t", "play", "\n"); 
   session:streamFile(sd .. msg[2]);
   session:sleep(1000);
   d = use();
   if (d ~= "0" and d ~= "3" and msg[1] ~= "") then
      read(aosd .. "morecontent.wav", 2000);
      d = use();
      if (d == "1") then
	 read(aosd .. "okcontent.wav", 500);
	 currfile = sd .. msg[1];
	 logfile:write(sessid, "\t", session:getVariable("caller_id_number"), "\t", os.time(), "\t", currfile, "\t", "play", "\n"); 
	 session:streamFile(sd .. msg[1]);
	 session:sleep(1000);
	 d = use();
      end
   end
   return d;
end


-----------
-- playtag
-----------

function playtag (tagid)
   tag = {};
   cur = con:execute("SELECT name_file, moderated, posting_allowed, responses_allowed, maxlength FROM tag WHERE ID = " .. tagid);
   cur:fetch(tag);
   cur:close();

   if (tag == nil) then
      freeswitch.consoleLog("info", script_name .. " : No such tag ID : " .. tagid .. "\n");
      read(aosd .. "notag.wav", 500)
      return use();
   end

   read(aosd .. "okyouwant.wav", 0);
   read(aosd .. tag[1], 1000);
	
   if (tag[3] == 'y') then
      read(aosd .. "recordorlisten.wav", 2000);
      d = use();

      if (d == "1") then
	 read(aosd .. "okrecord.wav", 1000);
	 d = use();
	 if (d ~= 0) then
	    d = recordmessage(tagid, nil, tag[2], tag[5]);
	 end
      end

      if (d == "0") then
	 return d;
      end
    
      read(aosd .. "okplay.wav", 1000);
   end

   read(aosd .. "instructions.wav", 1000);
   if (use() == "0") then
      return "0";
   end
   
   i = 0;
   for row in rows ("SELECT message.extra_content_file, message.content_file, message.ID, message.rgt, message.ID FROM message, message_tag WHERE message_tag.tag = " .. tagid .. " AND message_tag.status = 'live' AND message.ID = message_tag.message AND message.lft = 1 ORDER BY -message_tag.position DESC, message.date DESC") do
      rgt = tonumber(row[4]);
      i = i + 1;

      if (i == 1) then
	 -- reply to 1st message
	 arg = {tagid, row[3], tag[2], tag[5], rgt};
	 read(aosd .. "firstmessage.wav", 1000);
      else
	 -- reply to last message
	 read(aosd .. "nextmessage.wav", 1000);
	 arg = {tagid, row[3], tag[2], tag[5], rgt};
      end

      -- session:execute("playback", "tone_stream://%(500, 0, 620)");
      d = use();

      if (d ~= "0" and d ~= "3") then
	 d = playmessage(row);
      end

      -- if (d ~= "0" and d ~= "3" and rgt > 2) then
      if (d ~= "0" and rgt > 2) then
	 read(aosd .. "listenreplies.wav", 2000);
	 d = use();

	 if (d == "1") then
	    read(aosd .. "okreplies.wav", 500);
	    if (use() == "0") then
		return "0";
	    end
	     
	    j = 0;
	    for row_a in rows ("SELECT message.extra_content_file, message.content_file, message.ID, message.rgt FROM message, message_tag WHERE message.thread = " .. row[5] .. " AND message_tag.message = message.ID AND message_tag.status = 'live' ORDER BY message.lft ASC") do
	       j = j + 1;

	       if (j == 1) then
		  -- reply to 1st message
		  read(aosd .. "firstmessage.wav", 1000);
	       else
		  -- reply to last message
		  read(aosd .. "nextmessage.wav", 1000);
	       end

	       session:sleep(1000);
	       arg = {tagid, row[3], tag[2], tag[5], row_a[4]};

	       -- session:execute("playback", "tone_stream://%(500, 0, 620)");
	       d = use();
	    
	       if (d ~= "0" and d ~= "3") then
		  d = playmessage(row_a);
	       end
	       
	       if (d == "0") then
		  return d;
	       end
	    end
	    read(aosd .. "endreplies.wav", 1000);
	    read(aosd .. "backtoforum.wav", 1000);
	    d = use();
	 end
      end

      if (d == "0") then
	 return d;
      end
   end
   
   if (d == "0") then
      return d;
   end
   
   if (i == 0) then
      read(aosd .. "nomessages.wav", 1000);
   else
      read(aosd .. "endforum.wav", 1000);
   end

   return use();
end


-----------
-- recordmessage
-----------

function recordmessage (tagid, thread, moderated, maxlength, rgt)
   tagid = tagid or nil;
   thread = thread or nil;
   maxlength = maxlength or 60000;
   moderated = moderated or nil;
   maxlength = maxlength or 60000;
   rgt = rgt or 1;
   partfilename = os.time() .. ".wav";
   filename = sd .. partfilename;

   repeat
      read(aosd .. "pleaserecord.wav", 1000);
      d = use();
      if (d == "0") then
	 return d;
      end
      session:execute("playback", "tone_stream://%(500, 0, 620)");
      
      freeswitch.consoleLog("info", script_name .. " : Recording " .. filename .. "\n")
      session:execute("record", filename .. " " .. maxlength .. " 40 3");
      session:sleep(1000);
      use();
      
      read(aosd .. "hererecorded.wav", 1000);
      read(filename, 1000);
      read(aosd .. "notsatisfied.wav", 2000);
      d = use();
      if (d == "0") then
	 return satisfied;
      elseif (d ~= "1" and d ~= "2") then
	 return read(aosd .. "messagecancelled.wav", 500);
      end
   until (d == "1");
   
   query1 = "INSERT INTO message (user, content_file";
   query2 = " VALUES ('"..session:getVariable("caller_id_number").."','"..partfilename.."'";
   
   if (thread ~= nil) then
      query = "UPDATE message SET rgt=rgt+2 WHERE rgt >=" .. rgt .. " AND thread = " .. thread .. " OR ID = " .. thread;
      con:execute(query);
      freeswitch.consoleLog("info", script_name .. " : " .. query .. "\n")
      query = "UPDATE message SET lft=lft+2 WHERE lft >=" .. rgt .. " AND thread = " .. thread .. " OR ID = " .. thread;
      con:execute(query);
      freeswitch.consoleLog("info", script_name .. " : " .. query .. "\n")
      query1 = query1 .. ", thread, lft, rgt)";
      query2 = query2 .. ",'" .. thread .. "','" .. rgt .. "','" .. rgt+1 .. "')";
   else
      query1 = query1 .. ")";
      query2 = query2 .. ")";
   end
      
   query = query1 .. query2;
   con:execute(query);
   freeswitch.consoleLog("info", script_name .. " : " .. query .. "\n")
   id = {};
   cur = con:execute("SELECT LAST_INSERT_ID()");
   cur:fetch(id);
   freeswitch.consoleLog("info", script_name .. " : ID = " .. tostring(id[1]) .. "\n");
   
   if (tag ~= nil) then
      query1 = "INSERT INTO message_tag (message, tag";
      query2 = " VALUES ('"..id[1].."','"..tagid.."'";

      if (moderated ~= nil) then
	 if (moderated == 'y') then
	    status = 'live';
	 else
	    status = 'pending';
	 end
	 query1 = query1 .. ", status)";
	 query2 = query2 .. ",'" .. status .. "')";
      else
	 query1 = ")";
	 query2 = ")";
      end

      query = query1 .. query2;
      con:execute(query);
      freeswitch.consoleLog("info", script_name .. " : " .. query .. "\n")
   end
   
   read(aosd .. "okrecorded.wav", 500);
   return use();
end


-----------
-- MAIN 
-----------

-- answer the call
session:answer();

-- sleep for a sec
session:sleep(1000);

while (1) do
   -- choose the tag
   tagid = choosetag();

   if (tagid == 0) then
      break;
   end

   -- play the tag
   playtag(tagid);

   -- go back to the main menu
   read(aosd .. "mainmenu.wav", 1000);
end

-- say goodbye 
read(bsd .. "/zrtp/8000/zrtp-thankyou_goodbye.wav", 1000);

hangup();
