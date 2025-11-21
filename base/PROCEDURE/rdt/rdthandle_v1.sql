SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Trigger: rdtHandle_V1                                                */      
/* Creation Date: 19-Dec-2004                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Shong                                                    */      
/*                                                                      */      
/* Purpose:                                                             */      
/*                                                                      */      
/* Input Parameters: Mobile#, XML Message                               */      
/*                                                                      */      
/* Output Parameters: XML Message                                       */      
/*                                                                      */      
/* Return Status:                                                       */      
/*                                                                      */      
/* Usage: This SP is calling from the RDT server to get or push an      */      
/*        XML Message between SQL server and RDT server                 */      
/*                                                                      */      
/*                                                                      */      
/* Called By: RDT TelNet server or Web Server                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Rev  Author   Purposes                                   */      
/* 10-Aug-2007      Vicky    Add Printer Validation                     */      
/* 08-Sep-2007      Vicky    Fixes on when ESC from Menu, UOM show 6    */      
/*                           instead of Each                            */      
/* 22-Nov-2007 1.6  Shong    SOS90411 Display error in another screen   */      
/* 13-Nov-2008 1.7  Vicky    RDT 2.0 - Delete MsgQueue with status = 9  */      
/*                           (Vicky01)                                  */      
/* 02-Dec-2008 1.8  Vicky    RDT 2.0 - Add MsgExpired Config, add trace */      
/*                           (Vicky02)                                  */      
/* 02-Apr-2010 1.9  Shong    Performance tuning                         */      
/* 22-Jul-2010 1.10 Vicky    Add Paper Printer field (Vicky03)          */      
/* 04-Aug-2010 1.11 Shong    RDT Debug Mode - Insert into rdtMessage    */   
/* 27-Apr-2011 1.13 James    If V_UOM = '' then get rdt user defaultuom */
/*                           (james01)                                  */  
/************************************************************************/      
CREATE PROC  [RDT].[rdtHandle_V1]      
  @InMobile      INT ,      
  @InMessage     NVARCHAR(4000),      
  @OutMessage    NVARCHAR(4000) OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
      
   DECLARE      
      @nFunction   INT,      
      @nScn        INT,      
      @nErrNo      INT,      
      @nStep       INT,      
      @cErrMsg     NVARCHAR( 125),      
      @cActionKey  NVARCHAR( 3),      
      @dStartTime  DATETIME,      
      @dStartTime1 DATETIME,      
      @dEndTime    DATETIME,      
      @nTimeTaken  INT,      
      @nStartFunc  INT,      
      @nStartScn   INT,      
      @nStartStep  INT,       
      @nMsgQueueNo INT,     -- SOS90411      
      @nMsgQStatus NVARCHAR(1), -- SOS90411      
      @cStoredProcName NVARCHAR( 1024),    
      @nStartTranCnt INT,
      @cClientIP   VARCHAR( 15)
          
      
   SET @dStartTime = GETDATE()      
   SET @nErrNo = 0      
   SET @cErrMsg = ''      
   SET @nStartTranCnt = @@TRANCOUNT       
         
            
   WHILE @@TRANCOUNT > 0     
      COMMIT TRAN    
            
   IF @InMessage IS NULL OR @InMessage = ''      
      SET @InMessage =      
         '<?xml version="1.0" encoding="UTF-8"?>' +      
         '<FromRDT type="NO">' +      
            '<input id="I_Field01" value=" "/><input id="I_Field02" value=" "/>'  +      
         '</FromRDT>'      
      
   -- Get the function, screen, step from the XML (also assign a new mobile no if 1st time login)      
   BEGIN TRANSACTION TrnSetMobile;    
   EXEC RDT.rdtSetMobile      
      @InMobile    OUTPUT,      
      @InMessage,      
      @nFunction   OUTPUT,      
      @nScn        OUTPUT,      
      @nStep       OUTPUT,      
      @nMsgQueueNo OUTPUT, -- SOS90411      
      @nErrNo      OUTPUT,      
      @cErrMsg     OUTPUT      
  COMMIT TRAN TrnSetMobile;    
      
   -- Remember the in coming function, screen, step. Use in keep track of performance later      
   SET @nStartFunc = @nFunction      
   SET @nStartScn  = @nScn      
   SET @nStartStep = @nStep      
    
   -- Store a copy of the XML passed in        
   BEGIN TRANSACTION TrnrdtRecordXML;    
   EXEC RDT.rdtRecordXML @InMobile, 'IN', @InMessage      
   COMMIT TRANSACTION TrnrdtRecordXML;    
    
  -- Base on the XML received, update RDTMobRec.InFieldXX, and determine user press ENTER or ESC        
   BEGIN TRANSACTION TrnSetMobColRetAction;    
   --EXEC RDT.rdtSetMobColRetAction @InMobile, @InMessage, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cActionKey OUTPUT      
   EXEC RDT.rdtSetMobColRetAction @InMobile, @InMessage, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cActionKey OUTPUT, @cClientIP OUTPUT
   COMMIT TRANSACTION TrnSetMobColRetAction;    
         
   --Print 'HELLO'      
   -- SOS90411      
   IF @nMsgQueueNo > 0       
   BEGIN    
      BEGIN TRANSACTION TrnMsgQueue;    
             
      SELECT @nMsgQStatus = Status       
      FROM  RDT.rdtMsgQueue (NOLOCK)       
      WHERE MsgQueueNo = @nMsgQueueNo        
      AND   Mobile = @InMobile      
      
      IF @cActionKey = 'NO' AND @nMsgQStatus = '1' -- ENTER      
      BEGIN       
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK)       
            SET  MsgQueueNo = 0      
         WHERE  Mobile = @InMobile       
      
         -- RDT 2.0 - Delete MsgQueue (Vicky01) - Start      
         DELETE FROM  RDT.rdtMsgQueue       
         WHERE MsgQueueNo = @nMsgQueueNo       
           AND Mobile = @InMobile       
         -- RDT 2.0 - Delete MsgQueue (Vicky01) - End      
      
         SET @nMsgQueueNo = 0       
      END    
          
      COMMIT TRANSACTION TrnMsgQueue;      
   END      
   ELSE      
   BEGIN       
      IF @nFunction < 500 -- Menu      
      BEGIN    
         SET @nErrNo = 0     
         BEGIN TRANSACTION TrnMenu;    
               
         IF @cActionKey = 'YES' -- ENTER      
         BEGIN      
            IF @nFunction = 0  -- login screen      
            BEGIN    
               EXEC RDT.rdtLogin_V1 @InMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunction OUTPUT    
               SET @nErrNo = @@ERROR    
               IF @nErrNo <> 0     
                  GOTO EXIT_PROCESS_MENU    
            END    
            ELSE IF @nFunction = 1  -- storer and facility      
            BEGIN    
               EXEC rdt.rdtValidateStorernFacility @InMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunction OUTPUT    
               SET @nErrNo = @@ERROR    
               IF @nErrNo <> 0     
                  GOTO EXIT_PROCESS_MENU                   
            END    
            ELSE      
            BEGIN    
               -- Menu      
               EXEC RDT.rdtProcessMenu @InMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunction OUTPUT    
               SET @nErrNo = @@ERROR    
               IF @nErrNo <> 0     
                  GOTO EXIT_PROCESS_MENU                                    
            END    
         END -- @cActionKey = 'YES'     
         
         IF @cActionKey = 'NO' -- ESC      
         BEGIN      
   IF @nFunction <= 5   -- logout if at top level menu      
            BEGIN      
               IF @nFunction = 1      
               BEGIN    
                  UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET      
                     Scn = 0,      
                     Func = 0,      
                     Step = 0,      
                     Menu = 0 ,      
                     I_Field01 ='',      
                     I_Field02 ='',      
                     O_Field01 ='',      
                     O_Field02 ='' ,      
      ErrMsg = (CASE WHEN @nFunction <> 0 THEN 'Logged Off' ELSE '' END)      
                  WHERE MOBILE = @InMobile             
                  SET @nErrNo = @@ERROR    
                  IF @nErrNo <> 0     
                     GOTO EXIT_PROCESS_MENU                                 
               END    
         
               IF @nFunction = 5      
               BEGIN    
                  UPDATE MOB WITH (ROWLOCK) SET  -- (james01)
                     Scn = 1,      
                     Func = 1,      
                     Step = 0,      
                     Menu = 1 ,      
                     O_Field01 = StorerKey,      
                     O_Field02 = Facility,       
                     --O_Field03 = V_UOM,      
                     --Modified by Vicky on 08-Sep-2007      
                     O_Field03 = CASE V_UOM WHEN '1' THEN 'Pallet'      
                                            WHEN '2' THEN 'Carton'      
                                            WHEN '3' THEN 'Inner Pack'      
                                            WHEN '4' THEN 'Other Unit 1'      
                                            WHEN '5' THEN 'Other Unit 2'      
                                            WHEN '6' THEN 'Each'      
                                  --ELSE 'Each'   -- (james01)
                                            ELSE CASE DefaultUOM WHEN '1' THEN 'Pallet'
                                                                 WHEN '2' THEN 'Carton'
                                                                 WHEN '3' THEN 'Inner Pack'
                                                                 WHEN '4' THEN 'Other Unit 1'
                                                                 WHEN '5' THEN 'Other Unit 2'
                                                                 WHEN '6' THEN 'Each'
                                                                 ELSE 'Each' END
                                            END,   
                     O_Field04 = Printer, -- Added on 10-Aug-2007     
                     O_Field05 = Printer_Paper, -- (Vicky03)    
                     I_Field01 = '',      
                     I_Field02 = '',      
                     I_Field03 = '',      
                     I_Field04 = '', -- Added on 10-Aug-2007      
                     I_Field05 = '', -- (Vicky03)    
                     ErrMsg    = ''      
                  FROM RDT.RDTMOBREC MOB -- (james01)
                  JOIN RDT.RDTUSER RDTUSER ON MOB.USERNAME = RDTUSER.USERNAME -- (james01)
                  WHERE MOBILE = @InMobile    
                  SET @nErrNo = @@ERROR    
                  IF @nErrNo <> 0     
                     GOTO EXIT_PROCESS_MENU                                                                       
               END    
            END  --IF @nFunction <= 5    
            ELSE    
            BEGIN    
               -- Back to Previous Screen      
               EXEC RDT.rdtPrevScreen @InMobile, @nScn OUTPUT                 
               SET @nErrNo = @@ERROR    
               IF @nErrNo <> 0     
                  GOTO EXIT_PROCESS_MENU                        
            END        
         END -- @cActionKey = 'NO'    
         EXIT_PROCESS_MENU:    
         IF @nErrNo = 0     
            COMMIT TRANSACTION TrnMenu;    
         ELSE    
         BEGIN    
            IF @@TRANCOUNT > 0     
               ROLLBACK TRANSACTION TrnMenu;    
         END           
      END -- End Menu       
         
      IF @nFunction >= 500 -- Function      
      BEGIN      
         SET @nErrNo = 0     
         --BEGIN TRANSACTION TrnProcessFunction;    
                      
         SET @cStoredProcName = ''    
         -- Get the stor proc to execute      
         SELECT @cStoredProcName = StoredProcName      
         FROM RDT.RDTMsg WITH (NOLOCK)      
         WHERE Message_ID = @nFunction      
         
         -- Execute the stor proc      
         IF @cStoredProcName IS NOT NULL AND @cStoredProcName <> ''      
         BEGIN      
            -- SOS 39748 - stamp correct user on AddWho EditWho column - start      
            -- SETUSER pattern:      
            --   'RDT' --> 'A' --> 'RDT' --> 'B'  = OK      
            --   'RDT' --> 'A' --> 'B'            = ERROR      
         DECLARE      
                 @cUserName NVARCHAR(18)      
               , @cLangCode NVARCHAR( 3)      
               , @cDateFormat NVARCHAR( 3)      
         
            SELECT      
              @cUserName = UserName,      
              @cLangCode = Lang_Code      
            FROM rdt.rdtMobRec (NOLOCK)      
            WHERE mobile = @InMobile      
         
            SETUSER             -- Reset back to original sql login (i.e. RDT)      
            SETUSER @cUserName  -- Set it as the sql login that user key-in      
         
            SET @cDateFormat = RDT.rdtGetDateFormat( @cUserName)      
            SET DATEFORMAT @cDateFormat      
         
            SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)      
            SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @InMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'      
            EXEC sp_executesql @cStoredProcName , N'@InMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',      
               @InMobile,      
               @nErrNo OUTPUT,      
               @cErrMsg OUTPUT      
    
            SET @nErrNo = @@ERROR    
            IF @nErrNo <> 0     
               GOTO EXIT_PROCESS_FUNCTION        
                              
            SETUSER     -- Reset back to original sql login (i.e. RDT)      
            -- SOS 39748 - stamp correct user on AddWho EditWho column - end      
         END -- @cStoredProcName IS NOT NULL AND @cStoredProcName <> ''    
         ELSE      
         BEGIN      
            SET @cErrMsg = 'Function not defined yet'      
            IF @cActionKey = 'NO'      
               EXEC RDT.rdtPrevScreen @InMobile, @nScn OUTPUT      
         END      
             
         EXIT_PROCESS_FUNCTION:    
--         IF @nErrNo = 0     
--            COMMIT TRANSACTION TrnProcessFunction;    
--         ELSE    
--         BEGIN    
--            IF @@TRANCOUNT > 0     
--               ROLLBACK TRANSACTION TrnProcessFunction;    
--         END                 
      END -- End Function >= 500      
   END -- If MsgQueueNo = 0       
       
   -- Begin trans for the rest of the process     
   BEGIN TRAN ;    
       
   -- SOS90411 If Found a Message in the Message Queue rdtMsgQueue, then Show the Message 1st      
   -- (Vicky02) - Start      
   DECLARE @dMsgAddDate          DateTime,       
           @nMsgExpired          int       
   SET @nMsgQueueNo = 0       
   SET @dMsgAddDate = NULL      
      
   SELECT TOP 1 @nMsgQueueNo = ISNULL(MsgQueueNo, 0),       
          @dMsgAddDate = AddDate       
   FROM   RDT.rdtMsgQueue WITH (NOLOCK)      
   WHERE  Mobile = @InMobile       
     AND  Status < '9'         
   ORDER BY MsgQueueNo       
      
   SET @nMsgExpired = 0       
      
   SELECT @nMsgExpired = CASE WHEN ISNUMERIC(NSQLValue) = 1 THEN CAST(NSQLValue AS int) ELSE 0 END      
     FROM RDT.NSQLCONFIG (NOLOCK)       
    WHERE CONFIGKEY = 'MsgExpired' AND NSQLValue = '1'      
         
   IF @dMsgAddDate IS NOT NULL AND @nMsgQueueNo > 0  AND @nMsgExpired = 1      
   BEGIN      
      IF DATEDIFF(minute, @dMsgAddDate, GETDATE()) > 60 -- If msg stays in queue for more than 60 mins      
      BEGIN      
         DELETE FROM RDT.rdtMsgQueue       
         WHERE MsgQueueNo = @nMsgQueueNo       
           AND Mobile = @InMobile       
      
         SET @nMsgQueueNo = 0      
      END      
   END      
      
   IF @nMsgQueueNo > 0       
   BEGIN       
     -- Set Trace         
      SET @dStartTime1 = GETDATE()      
       
      EXEC RDT.rdtGetMsgScreen @InMobile, @nMsgQueueNo, @OutMessage OUTPUT       
            
      SET  @dEndTime = GETDATE()      
      SET  @nTimeTaken = CAST( DATEDIFF( ms, @dStartTime1, @dEndTime) AS INT)      
      EXEC RDT.rdtSetTrace @InMobile ,999, 999, 1, @dStartTime1, @dEndTime, @nTimeTaken      
   -- (Vicky02) - End                 
   END  -- Process Message Queue       
   ELSE       
   BEGIN       
      -- Get the new screen and function, after executed the stor proc      
      SELECT      
         @nScn = Scn,      
@nFunction = Func      
      FROM RDT.rdtMobRec (NOLOCK)      
      WHERE Mobile = @InMobile      
         
      -- Populate the XML temporary table      
      IF @nFunction Between 5 AND 499      
         EXEC RDT.rdtGetMenu_V1 @InMobile -- Menu      
      ELSE       
      BEGIN      
         EXEC RDT.rdtGetScreen_V1 @InMobile, @cActionKey -- Functional      
         EXEC RDT.rdtChgScreen @InMobile      
      END      
         
      -- Create the XML, base on temporary tables      
      DECLARE @XML_Text NVARCHAR( 4000)      
      SET @XML_Text = ''      
      EXEC RDT.rdtGetXML_V1 @InMobile, @XML_Text OUTPUT      
          
      -- Send out the XML      
      IF RTRIM( @XML_Text) IS NOT NULL      
      BEGIN      
         SET @OutMessage = RTRIM( @XML_Text)      
      END      
      ELSE      
      BEGIN      
         SET @OutMessage =       
            '<ToRDT number="' + RTRIM( CAST( @InMobile AS NVARCHAR( 10))) + '">' +      
               '<field typ="output" x="00" y="01" value="InMobile MOB :' + RTRIM( CAST( @InMobile AS NVARCHAR( 10))) + '"/>' +     
               '<field typ="output" x="00" y="02" value="Parsing Error"/>' +      
               '<field typ="output" x="00" y="03" value="No records found in #XML"/>' +      
               '<field typ="input" x="25" y="03" length="1" id="Field01"/>' +      
            '</ToRDT>'      
      END      
      -- Keep track of performance      
      SET @dEndTime = GETDATE()      
      SET @nTimeTaken = CAST( DATEDIFF( ms, @dStartTime, @dEndTime) AS INT)      
      EXEC RDT.rdtSetTrace @InMobile ,@nStartFunc, @nStartScn, @nStartStep, @dStartTime, @dEndTime, @nTimeTaken      
   END      
         
   -- Record the XML being send out      
   EXEC RDT.rdtRecordXML @InMobile , 'OUT', @OutMessage      
      
   -- For debugging      
   IF EXISTS(SELECT 1 FROM RDT.NSQLConfig WITH (NOLOCK) WHERE ConfigKey = 'RDTDebugMode'    
             AND nSQLValue = '1')    
   BEGIN    
      INSERT INTO RDT.RDTMessage(Mobile, Message, MessageOut, InFunc, InScn, InStep)     
      VALUES (@InMobile, @InMessage, @OutMessage, @nStartFunc, @nStartScn, @nStartStep)      
   END    
     
   IF @@TRANCOUNT < ISNULL(@nStartTranCnt,0)     
   BEGIN    
      WHILE @@TRANCOUNT < ISNULL(@nStartTranCnt,0)    
         BEGIN TRAN;          
   END    
   ELSE    
   IF @@TRANCOUNT > ISNULL(@nStartTranCnt,0)    
   BEGIN    
      WHILE @@TRANCOUNT > ISNULL(@nStartTranCnt,0)       
         COMMIT TRAN;          
   END       
END

GO