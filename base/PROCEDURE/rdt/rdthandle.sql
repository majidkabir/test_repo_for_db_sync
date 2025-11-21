SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************/      
/* Trigger: rdtHandle                                                   */      
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
/* 29-Feb-2012 1.12 Ung      Fix begin tran without commit tran         */      
/*                           Remove trans when exec function, prevent   */      
/*                           @@trancount not match if function rollback */      
/* 27-Apr-2011 1.13 James    If V_UOM = '' then get rdt user defaultuom */      
/*                           (james01)                                  */      
/* 12-Mar-2012 1.14 Ung      SOS235841 Add rdt login record             */      
/* 22-May-2012 1.15 Ung      SOS245172 Fix field attr not reset (ung01) */      
/* 29-Oct-2012 1.16 ChewKP   Enhancement for RDTTrace (ChewKP01)        */      
/* 18-Mar-2013 1.17 Ung      SOS271056 Add DeviceID                     */      
/* 12-Nov-2014 1.18 Ung      Performance tuning to prevent recompile    */      
/* 17-Sep-2015 1.19 Ung      SOS349992 Fix DeviceID field disabled     */      
/* 02-Oct-2015 1.20 Ung      Performance tuning for CN Nov 11           */      
/* 15-Aug-2016 1.21 Ung      Update rdtMobRec with EditDate             */      
/* 14-Feb-2017 1.22 Ung      Add NOLOCK                             */      
/* 07-Nov-2017 1.23 Ung      Remove tran for message queue              */      
/* 14-May-2018 1.24 Ung      INC0220859 Fix msgQueue del scn not refresh*/      
/* 18-Apr-2019 1.25 YeeKung  Fix handheld incorrect logout  (yeekung01) */  
/* 24-Mar-2020 1.28 YeeKng   Add two inputfield username (yeekung02)    */            
/************************************************************************/      
CREATE  PROC  [RDT].[rdtHandle]      
  @InMobile      INT ,      
  @InMessage     NVARCHAR(MAX),      
  @OutMessage    NVARCHAR(MAX) OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
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
      @nTimeTaken1 INT,      
      @nStartFunc  INT,      
      @nStartScn   INT,      
      @nStartStep  INT,      
      @nMsgQueueNo INT,     -- SOS90411      
      @nMsgQStatus NVARCHAR(1), -- SOS90411      
      @cStoredProcName NVARCHAR( 1024),      
      @cClientIP   NVARCHAR( 15),      
      @cUserName   NVARCHAR(18)      
      
   SET @dStartTime = GETDATE()      
   SET @nTimeTaken1 = 0      
   SET @nErrNo = 0      
   SET @cErrMsg = ''      
      
   WHILE @@TRANCOUNT > 0      
      COMMIT TRAN      
      
   IF @InMessage IS NULL OR @InMessage = ''      
      SET @InMessage =      
         '<?xml version="1.0" encoding="UTF-16"?>' +      
         '<FromRDT type="NO">' +      
            '<input id="I_Field01" value=" "/><input id="I_Field02" value=" "/>'  +      
         '</FromRDT>'      
   ELSE      
      SELECT @InMessage = REPLACE( @InMessage, 'encoding="UTF-8"', 'encoding="UTF-16"')      
      
   -- Get the function, screen, step from the XML (also assign a new mobile no if 1st time login)      
   EXEC RDT.rdtSetMobile      
      @InMobile    OUTPUT,      
      @InMessage,      
      @nFunction   OUTPUT,      
      @nScn        OUTPUT,      
      @nStep       OUTPUT,      
      @nMsgQueueNo OUTPUT, -- SOS90411      
      @nErrNo      OUTPUT,      
      @cErrMsg     OUTPUT      
      
   -- Remember the in coming function, screen, step. Use in keep track of performance later      
   SET @nStartFunc = @nFunction      
   SET @nStartScn  = @nScn      
   SET @nStartStep = @nStep      
      
   -- Store a copy of the XML passed in      
   -- EXEC RDT.rdtRecordXML @InMobile, 'IN', @InMessage      
      
   -- Base on the XML received, update RDTMobRec.InFieldXX, and determine user press ENTER or ESC      
   EXEC RDT.rdtSetMobColRetAction @InMobile, @InMessage, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cActionKey OUTPUT, @cClientIP OUTPUT      
      
   --Print 'HELLO'      
   -- SOS90411      
   IF @nMsgQueueNo > 0      
   BEGIN      
      EXEC RDT.rdtHandleMsgQueue  @InMobile,@cActionKey,@nMsgQueueNo OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT       --(yeekung02)      
      -- COMMIT TRANSACTION TrnMsgQueue;      
   END      
   ELSE      
   BEGIN      
      IF @nFunction < 500 -- Menu      
      BEGIN      
         SET @nErrNo = 0      
      
         IF @cActionKey = 'YES' -- ENTER      
         BEGIN      
            IF @nFunction = 0  -- login screen      
            BEGIN      
               EXEC RDT.rdtLogin @InMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunction OUTPUT, @cClientIP      
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
            ELSE IF @nFunction = 2  -- Continue Screen (yeekung01)              
            BEGIN              
               EXEC rdt.RDTResumeSession @InMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunction OUTPUT, @cClientIP                 
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
         END      
      
         IF @cActionKey = 'NO' -- ESC      
         BEGIN      
            IF @nFunction <= 5   -- logout if at top level menu      
            BEGIN      
               IF @nFunction = 1      
               BEGIN      
                  UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET      
                     EditDate = GETDATE(),       
                     Scn = 0,      
                     Func = 0,      
                     Step = 0,      
                     Menu = 0 ,      
                     I_Field01 ='',      
                     I_Field02 ='',      
                     O_Field01 ='',      
                     O_Field02 ='',      
                     FieldAttr01 = '',      
                     FieldAttr02 = '',      
                     ErrMsg = (CASE WHEN @nFunction <> 0 THEN 'Logged Off' ELSE '' END)      
                  WHERE MOBILE = @InMobile      
                  SET @nErrNo = @@ERROR      
                  IF @nErrNo <> 0      
                     GOTO EXIT_PROCESS_MENU      
      
      
                  -- Insert logout data      
                  SELECT @cUserName = UserName FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @InMobile      
                  INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks)      
                  VALUES (@cUsername, @InMobile, @cClientIP, 'Logout')      
                  IF @@ERROR <> 0      
                     GOTO EXIT_PROCESS_MENU      
               END      
      
               IF @nFunction = 2  --(yeekung01)          
               BEGIN            
                  UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET                      
                     EditDate = GETDATE(),                       
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
                      
                                        
                  -- Insert logout data                      
                  SELECT @cUserName = UserName FROM rdt.rdtMobRec WHERE Mobile = @InMobile                      
                  INSERT INTO RDT.rdtLoginLog (UserName, Mobile, ClientIP, Remarks)                      
                  VALUES (@cUsername, @InMobile, @cClientIP, 'Logout')                      
                  IF @@ERROR <> 0                      
                     GOTO EXIT_PROCESS_MENU             
               END        
      
               IF @nFunction = 5      
               BEGIN      
                  UPDATE MOB WITH (ROWLOCK) SET  -- (james01)      
                     EditDate = GETDATE(),       
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
                     O_Field06 = DeviceID,      
                     I_Field01 = '',      
                     I_Field02 = '',      
                     I_Field03 = '',      
                     I_Field04 = '', -- Added on 10-Aug-2007      
                     I_Field05 = '', -- (Vicky03)      
                     I_Field06 = '',      
                     FieldAttr01 = '', -- (ung01)      
                     FieldAttr02 = '',      
                     FieldAttr03 = '',      
                     FieldAttr04 = '',      
                     FieldAttr05 = '',      
                     FieldAttr06 = '',      
                     ErrMsg    = ''      
                  FROM RDT.RDTMOBREC MOB -- (james01)      
                  JOIN RDT.RDTUSER RDTUSER WITH (NOLOCK) ON MOB.USERNAME = RDTUSER.USERNAME -- (james01)      
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
         END      
      
         EXIT_PROCESS_MENU:      
      END -- End Menu      
      
      IF @nFunction >= 500 -- Function      
      BEGIN      
         SET @nErrNo = 0      
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
            DECLARE @cLangCode NVARCHAR( 3)      
            DECLARE @cDateFormat NVARCHAR( 3)      
      
            SELECT      
              @cUserName = UserName,      
              @cLangCode = Lang_Code      
            FROM rdt.rdtMobRec (NOLOCK)      
            WHERE mobile = @InMobile      
      
            SET @dStartTime1 = GETDATE()      
            EXEC rdt.rdtHandle_SetUser @InMobile , @nFunction, @cLangCode, @cUserName, @cStoredProcName,      
               @nErrNo  OUTPUT,      
               @cErrMsg OUTPUT      
      
            SET @dEndTime = GETDATE()      
            SET @nTimeTaken1 = CAST( DATEDIFF( ms, @dStartTime1, @dEndTime) AS INT)      
      
            /*      
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
      
            SETUSER     -- Reset back to original sql login (i.e. RDT)      
            -- SOS 39748 - stamp correct user on AddWho EditWho column - end      
            */      
         END -- @cStoredProcName IS NOT NULL AND @cStoredProcName <> ''      
         ELSE      
         BEGIN      
            SET @cErrMsg = 'Function not defined yet'      
            IF @cActionKey = 'NO'      
               EXEC RDT.rdtPrevScreen @InMobile, @nScn OUTPUT      
         END      
      END -- End Function >= 500      
   END -- If MsgQueueNo = 0      
      
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
      SET @nTimeTaken = CAST( DATEDIFF( ms, @dStartTime, @dEndTime) AS INT)      
      SET @nTimeTaken1 = CAST( DATEDIFF( ms, @dStartTime1, @dEndTime) AS INT)      
      EXEC RDT.rdtSetTrace @InMobile ,999, 999, 1, @dStartTime, @dEndTime, @nTimeTaken, @nTimeTaken1      
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
      
      -- Create the XML      
      DECLARE @cXML NVARCHAR( MAX)      
      SET @cXML = ''      
      
      IF @nFunction Between 5 AND 499      
         EXEC RDT.rdtGetMenu @InMobile, @cXML OUTPUT    -- Menu      
      ELSE      
         EXEC RDT.rdtGetScreen @InMobile, @cXML OUTPUT  -- Functional      
      
      -- Wrap the XML with header and footer      
      EXEC RDT.rdtGetXML @InMobile, @cXML OUTPUT      
      
      -- Send out the XML      
      IF RTRIM( @cXML) IS NOT NULL      
      BEGIN      
         SET @OutMessage = RTRIM( @cXML)      
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
      SET @nTimeTaken1 = @nTimeTaken - @nTimeTaken1      
      EXEC RDT.rdtSetTrace @InMobile ,@nStartFunc, @nStartScn, @nStartStep, @dStartTime, @dEndTime, @nTimeTaken, @nTimeTaken1      
   END      
      
   -- Record the XML being send out      
   -- EXEC RDT.rdtRecordXML @InMobile , 'OUT', @OutMessage      
      
   -- For debugging      
   IF EXISTS(SELECT 1 FROM RDT.NSQLConfig WITH (NOLOCK) WHERE ConfigKey = 'RDTDebugMode'      
             AND nSQLValue = '1')      
   BEGIN      
      SELECT @InMessage = REPLACE( @InMessage, 'encoding="UTF-8"', 'encoding="UTF-16"')     -- (ChewKP01)      
      SELECT @OutMessage = REPLACE( @OutMessage, 'encoding="UTF-8"', 'encoding="UTF-16"')   -- (ChewKP01)      
      
      INSERT INTO RDT.RDTMessage(Mobile, Message, MessageOut, InFunc, InScn, InStep)      
      VALUES (@InMobile, @InMessage, @OutMessage, @nStartFunc, @nStartScn, @nStartStep)      
   END      
      
   WHILE @@TRANCOUNT > 0      
      COMMIT TRAN      
END 

GO