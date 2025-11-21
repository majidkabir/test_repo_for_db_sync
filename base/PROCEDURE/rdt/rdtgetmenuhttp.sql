SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: rdtGetMenuHttp                                         */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Build the screen format for the Menu screen, which setup       */
/*          in rdtMenu table.                                              */
/*                                                                         */
/* Date         Ver. Author    Purposes                                    */
/* 26-Sep-2023  1.0  YZH230    Created base on rdtGetMenu ver 2.3          */
/* 03-Nov-2023  1.1  JLC042    Remove Menu Header                          */
/***************************************************************************/

CREATE   PROC [RDT].[rdtGetMenuHttp] (
   @nMobile    INT,
   @cXML       NVARCHAR(MAX) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nOption1    INT
   DECLARE @nOption2    INT
   DECLARE @nOption3    INT
   DECLARE @nOption4    INT
   DECLARE @nOption5    INT
   DECLARE @nOption6    INT
   DECLARE @nOption7    INT
   DECLARE @nOption8    INT
   DECLARE @nOption9    INT

   DECLARE @nScreen     INT
   DECLARE @nMenu       INT
   DECLARE @cLangCode   NVARCHAR(3)
   DECLARE @cUserName   NVARCHAR(15)
   DECLARE @cErrMsg     NVARCHAR(125)

   DECLARE @nMsgID      INT
   DECLARE @cMsgType    NVARCHAR(3)
   DECLARE @cMsgText    NVARCHAR(80)
   DECLARE @cMobileDisp NVARCHAR(1)
   DECLARE @cLine       NVARCHAR(3)
   DECLARE @nLine       INT
   DECLARE @nCount      INT

   -- Get session info
   SELECT 
      @nMenu = Menu,
      @cErrMsg = ErrMsg,
      @cLangCode = Lang_Code,
      @cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get user info
   SELECT @cMobileDisp = ISNULL( MobileNo_Display, 'Y') 
   FROM rdt.rdtUser WITH (NOLOCK) 
   WHERE UserName = @cUserName

   -- Get menu info
   SELECT 
      @nOption1 = OP1, 
      @nOption2 = OP2, 
      @nOption3 = OP3,
      @nOption4 = OP4, 
      @nOption5 = OP5, 
      @nOption6 = OP6,
      @nOption7 = OP7,
      @nOption8 = OP8,
      @nOption9 = OP9
   FROM RDT.RDTMenu WITH (NOLOCK) 
   WHERE MenuNo = @nMenu

   -- Menu
   SET @nLine = 1
   SET @nCount = 1
   WHILE (1=1)
   BEGIN
      -- Get menu option
      SET @nMsgID = 0
      IF @nCount = 1 SET @nMsgID = @nOption1 ELSE
      IF @nCount = 2 SET @nMsgID = @nOption2 ELSE
      IF @nCount = 3 SET @nMsgID = @nOption3 ELSE
      IF @nCount = 4 SET @nMsgID = @nOption4 ELSE
      IF @nCount = 5 SET @nMsgID = @nOption5 ELSE
      IF @nCount = 6 SET @nMsgID = @nOption6 ELSE
      IF @nCount = 7 SET @nMsgID = @nOption7 ELSE
      IF @nCount = 8 SET @nMsgID = @nOption8 ELSE
      IF @nCount = 9 SET @nMsgID = @nOption9 
      
      -- If Menu not setup, return blank line (james02)
      IF @nMsgID = 0
      BEGIN
         SET @cLine = CAST( @nLine AS NVARCHAR(2))
         SET @cMsgText = ''
         EXEC RDT.rdtScr2XMLHttp @nMobile, @cLangCode, NULL, @cLine, @cMsgText, @cXML OUTPUT
         SET @nLine = @nLine + 1
      END

      -- Menu is setup (can be blank, not setup)
      IF @nMsgID > 0
      BEGIN
         -- Determine is a menu or function
         IF @nMsgID BETWEEN 5 AND 499
            SET @cMsgType = 'MNU'
         ELSE
            SET @cMsgType = 'FNC'
   
         -- Get menu text
         SET @cMsgText = CAST( @nCount as NVARCHAR(1)) + '. ' + rdt.rdtgetmessage( @nMsgID, @cLangCode, @cMsgType)
      
         -- Build menu
         IF @cMsgText <> ''
         BEGIN
            SET @cLine = CAST( @nLine AS NVARCHAR(2))
            SET @cMsgText = rdt.rdtReplaceSpecialCharInXMLData( @cMsgText)
            EXEC RDT.rdtScr2XMLHttp @nMobile, @cLangCode, NULL, @cLine, @cMsgText, @cXML OUTPUT
            SET @nLine = @nLine + 1
         END
      END
   
      -- Exit condition
      IF @nCount = 9 OR                       -- Handheld display 6 menu options
         (@nCount = 2 AND @cMobileDisp = 'N') -- Wirst display 2 menu options
         BREAK
      
      SET @nCount = @nCount + 1
   END

   -- Option line
   SET @cMsgText = rdt.rdtgetmessage( 800, @cLangCode, 'ACT') -- OPTION:
   SET @cMsgText = rdt.rdtReplaceSpecialCharInXMLData( @cMsgText)
   IF @cMobileDisp = 'Y'
      SET @nLine = 12
   SET @cLine = CAST( @nLine AS NVARCHAR(2))
   EXEC RDT.rdtScr2XMLHttp @nMobile, @cLangCode, NULL, @cLine, @cMsgText, @cXML OUTPUT
   SET @cXML = @cXML + '<field typ="input" x="12" y="' + @cLine + '" length="01" id="I_Field01" color="" match=""/>'

   -- Error message line
   IF @cErrMsg IS NOT NULL AND @cErrMsg <> ''
   BEGIN
      IF @cMobileDisp = 'Y'
         SET @nLine = 14
      ELSE
         SET @nLine = @nLine + 1
      SET @cLine = CAST( @nLine AS NVARCHAR(2))
      SET @cErrMsg = rdt.rdtReplaceSpecialCharInXMLData( @cErrMsg)
      EXEC RDT.rdtScr2XMLHttp @nMobile, @cLangCode, NULL, @cLine, @cErrMsg, @cXML OUTPUT
   END

   -- Reset focus (before going into function)
   UPDATE RDT.RDTXML_Root WITH (ROWLOCK) SET 
      Focus = NULL 
   WHERE Mobile = @nMobile  

GO