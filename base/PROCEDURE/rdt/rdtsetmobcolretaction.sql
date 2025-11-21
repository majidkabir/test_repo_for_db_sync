SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/******************************************************************************/  
/* Copyright: IDS                                                             */  
/*                                                                            */  
/* Purpose: Base on the XML received from JBOSS, update RDTMobRec.InFieldXX   */  
/*          fields. And also user press ENTER or ESC, to send back the XML    */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author   Rev  Purposes                                        */  
/* 2006-02-06   Manny    1.0  Optimization. Merged rdtGetActionKey and        */  
/*                            rdtSetMobCol as rdtSetMobColRetAction           */  
/* 2006-07-04   Ung      1.1  Fixed InputKey column not updated when screen   */  
/*                            has no input field                              */  
/* 2006-07-10   Shong    1.2  Making used of the other columns in rdtMobRec   */  
/*                            like V_SKU, V_UOM                               */  
/* 2012-03-12   Ung      1.3  SOS235841 Add rdt login record                  */  
/* 2013-06-27   Ung      1.4  Support V_Max                                   */  
/* 2015-04-28   ChewKP   1.5  SOS#339806 - Add StringExp features (ChewKP01)  */  
/* 2014-09-19   Ung      1.6  Fix parse fail due to data contain single quote */  
/* 2015-10-15   Ung      1.7  Performance tuning for CN Nov 11                */  
/* 2016-08-09   Ung      1.8  Performance tuning for SQL 2014                 */  
/* 2017-02-08   James    1.9  Add function (F1-F4) key process                */  
/* 2017-11-03   YeeKung  2.0  Performance tuning for CN Nov 11                */  
/* 2018-10-03   Ung      2.1  INC0383981 V_Field need case sensitive in XML   */   
/* 2018-09-25   Ung      2.2  WMS-6410 Add field 16-20                        */
/* 2023-04-11   James    2.3  WMS-22147 Support V_Barcode (james01)           */  
/* 2023-06-02   James    2.4  Change V_MAX to V_Max (james02)                 */  
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdtSetMobColRetAction] (  
   @nMobile    INT,  
   @cInMessage NVARCHAR( 4000),  
   @nErrNo     INT             OUTPUT,  
   @cErrMsg    NVARCHAR( 1024) OUTPUT,  
   @cActionKey NVARCHAR( 3)    OUTPUT,   
   @cClientIP  NVARCHAR( 15)   OUTPUT  
)  
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE   
   @iDoc                INT,   
   @cColName            NVARCHAR( 20),  
   @cColValue           NVARCHAR( MAX),  
   @cSQL                NVARCHAR( 4000),  
   @nScn                INT,  
   @cColStringExp       NVARCHAR( 100),  
   @cColStringExpValue  NVARCHAR( 100),  
   @cColStringExpSQL    NVARCHAR( 4000),   
   @cStringExpValue     NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( 1000),  
   @cLangCode           NVARCHAR( 3),   
   @nInputKey           INT  

-- Get client IP  
DECLARE @iStart INT  
DECLARE @iLength INT  
SET @cClientIP = ''  
SET @iStart = CHARINDEX( 'clientIP="', @cInMessage)  
IF @iStart > 0  
BEGIN  
   SET @iStart = @iStart + LEN( 'clientIP="')  
   SET @iLength = CHARINDEX( '"', SUBSTRING( @cInMessage, @iStart, LEN( @cInMessage)))  
   SET @cClientIP = SUBSTRING( @cInMessage, @iStart, ABS( @iLength - 1))  
END  
  
-- Get ActionKey  
-- (james01)  
SET @cActionKey =''  
  
IF CHARINDEX( 'type="YES"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'YES' -- ENTER   
   SET @nInputKey = 1  
END  
ELSE IF CHARINDEX( 'type="NO"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'NO' -- ENTER   
   SET @nInputKey = 0  
END  
ELSE IF CHARINDEX( 'type="F1"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'F1' -- F1   
   SET @nInputKey = 11  
END   
ELSE IF CHARINDEX( 'type="F2"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'F2' -- F2   
   SET @nInputKey = 12  
END  
ELSE IF CHARINDEX( 'type="F3"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'F3' -- F3   
   SET @nInputKey = 13  
END  
ELSE IF CHARINDEX( 'type="F4"', @cInMessage) > 0   
BEGIN  
   SET @cActionKey = 'F4' -- F4   
   SET @nInputKey = 14  
END   
  
-- Get ActionKey  
IF @cActionKey IN ('YES', 'F1', 'F2', 'F3', 'F4')  
BEGIN  
   --SET @cActionKey = 'YES' -- ENTER   
/*  
   -- Get a  handle for the XML doc  
   EXEC sp_xml_preparedocument @iDoc OUTPUT, @cInMessage  
     
   -- Transform XML string into table  
   INSERT INTO @XML_Row  
   SELECT *   
   FROM OPENXML (@iDoc, '/fromRDT/input', 2) WITH   
      (  
         Col     NVARCHAR( 20) '@id',  
         Value   NVARCHAR( MAX) '@value'  
      )  
     
   -- Release the handle  
   EXEC sp_xml_removedocument @iDoc  
*/  
  
  
   DECLARE @xInMessage XML  
   SET @xInMessage = @cInMessage  
     
   SET @cSQL = ''  
  
   -- (ChewKP01)   
   SELECT   
      @nScn = Scn,   
      @cLangCode = Lang_Code   
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
  
   IF NOT EXISTS( SELECT 1 FROM rdt.rdtScnDetail WITH (NOLOCK) WHERE Scn = @nScn AND Lang_Code = @cLangCode)  
      SET @cLangCode = 'ENG'  
  
   IF EXISTS( SELECT 1   
      FROM rdt.rdtScnDetail WITH (NOLOCK)  
      WHERE scn = @nScn  
         AND ColStringExp <> ''  
         AND Lang_Code = @cLangCode)  
   BEGIN  
      SET @cColName = ''  
      SET @cColValue = ''  
  
      -- Loop for all input field  
      WHILE 1 = 1  
      BEGIN  
         SET ANSI_NULLS ON  
         SET ANSI_PADDING ON  
         SET ANSI_WARNINGS ON  
         -- SET ARITHABORT ON  
         SET CONCAT_NULL_YIELDS_NULL ON  
         -- SET NUMERIC_ROUNDABORT OFF  
         SET QUOTED_IDENTIFIER ON  
  
         SELECT TOP 1  
            @cColName  =m.c.value('@id', 'nvarchar(20)'),   
            @cColValue =m.c.value('@value', 'nvarchar(60)')   
         FROM @xInMessage.nodes('/fromRDT/input') AS m(c)  
         WHERE @xInMessage.exist ('/fromRDT/input[@id]') = 1  
            AND m.c.value('@id', 'nvarchar(20)') > @cColName  
         ORDER BY m.c.value('@id', 'nvarchar(20)');  
  
         IF @@ROWCOUNT = 0  
            BREAK  
  
         SET ANSI_NULLS OFF  
         SET ANSI_PADDING OFF  
         SET ANSI_WARNINGS OFF  
         -- SET ARITHABORT ON  
         SET CONCAT_NULL_YIELDS_NULL OFF  
         -- SET NUMERIC_ROUNDABORT OFF  
           
         SELECT @cColStringExp = ColStringExp   
         FROM rdt.rdtScnDetail WITH (NOLOCK)  
         WHERE scn = @nScn  
            AND FieldNo = RIGHT(@cColName,2 )   
            AND Lang_Code = @cLangCode  
        
         IF ISNULL(RTRIM(@cColStringExp),'') <> ''  
         BEGIN  
            SET @cColStringExpValue = REPLACE ( @cColStringExp , '<value>' , '@cColValue' )   
     
            SET @cColStringExpSQL = 'SELECT @cStringExpValue = ' +  @cColStringExpValue  
                 
            SET @cSQLParam =   
               ' @cColValue       NVARCHAR(MAX) ,           ' +  
               ' @cStringExpValue NVARCHAR(MAX) OUTPUT           '  
       
            EXEC sp_ExecuteSQL @cColStringExpSQL, @cSQLParam, @cColValue , @cStringExpValue OUTPUT  
              
            SET @cColValue = @cStringExpValue  
              
            SET ANSI_NULLS ON  
            SET ANSI_PADDING ON  
            SET ANSI_WARNINGS ON  
            -- SET ARITHABORT ON  
            SET CONCAT_NULL_YIELDS_NULL ON  
            -- SET NUMERIC_ROUNDABORT OFF  
  
            --update the value   
            SET @xInMessage.modify('    
            replace value of (/fromRDT/input[@id=sql:variable("@cColName")]/@value)[1]    
            with   sql:variable("@cColValue")    
            ');   
  
            SET ANSI_NULLS OFF  
            SET ANSI_PADDING OFF  
            SET ANSI_WARNINGS OFF  
            -- SET ARITHABORT ON  
            SET CONCAT_NULL_YIELDS_NULL OFF  
            -- SET NUMERIC_ROUNDABORT OFF  
            SET QUOTED_IDENTIFIER OFF  
         END  
      END  
   END  
     
   SET ANSI_NULLS ON  
   SET ANSI_PADDING ON  
   SET ANSI_WARNINGS ON  
   -- SET ARITHABORT ON  
   SET CONCAT_NULL_YIELDS_NULL ON  
   -- SET NUMERIC_ROUNDABORT OFF  
   SET QUOTED_IDENTIFIER ON  
  
   --update the mobile record  
  
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET  
      EditDate = GETDATE(),   
      InputKey = @nInputKey,  
      I_Field01 = ISNULL( Rw.value('(input[@id="I_Field01"]/@value)[1]','nvarchar(60)'), I_Field01),   
      I_Field02 = ISNULL( Rw.value('(input[@id="I_Field02"]/@value)[1]','nvarchar(60)'), I_Field02),   
      I_Field03 = ISNULL( Rw.value('(input[@id="I_Field03"]/@value)[1]','nvarchar(60)'), I_Field03),   
      I_Field04 = ISNULL( Rw.value('(input[@id="I_Field04"]/@value)[1]','nvarchar(60)'), I_Field04),   
      I_Field05 = ISNULL( Rw.value('(input[@id="I_Field05"]/@value)[1]','nvarchar(60)'), I_Field05),   
      I_Field06 = ISNULL( Rw.value('(input[@id="I_Field06"]/@value)[1]','nvarchar(60)'), I_Field06),   
      I_Field07 = ISNULL( Rw.value('(input[@id="I_Field07"]/@value)[1]','nvarchar(60)'), I_Field07),   
      I_Field08 = ISNULL( Rw.value('(input[@id="I_Field08"]/@value)[1]','nvarchar(60)'), I_Field08),   
      I_Field09 = ISNULL( Rw.value('(input[@id="I_Field09"]/@value)[1]','nvarchar(60)'), I_Field09),   
      I_Field10 = ISNULL( Rw.value('(input[@id="I_Field10"]/@value)[1]','nvarchar(60)'), I_Field10),   
      I_Field11 = ISNULL( Rw.value('(input[@id="I_Field11"]/@value)[1]','nvarchar(60)'), I_Field11),   
      I_Field12 = ISNULL( Rw.value('(input[@id="I_Field12"]/@value)[1]','nvarchar(60)'), I_Field12),   
      I_Field13 = ISNULL( Rw.value('(input[@id="I_Field13"]/@value)[1]','nvarchar(60)'), I_Field13),   
      I_Field14 = ISNULL( Rw.value('(input[@id="I_Field14"]/@value)[1]','nvarchar(60)'), I_Field14),   
      I_Field15 = ISNULL( Rw.value('(input[@id="I_Field15"]/@value)[1]','nvarchar(60)'), I_Field15),   
      I_Field16 = ISNULL( Rw.value('(input[@id="I_Field16"]/@value)[1]','nvarchar(60)'), I_Field16), 
      I_Field17 = ISNULL( Rw.value('(input[@id="I_Field17"]/@value)[1]','nvarchar(60)'), I_Field17), 
      I_Field18 = ISNULL( Rw.value('(input[@id="I_Field18"]/@value)[1]','nvarchar(60)'), I_Field18), 
      I_Field19 = ISNULL( Rw.value('(input[@id="I_Field19"]/@value)[1]','nvarchar(60)'), I_Field19), 
      I_Field20 = ISNULL( Rw.value('(input[@id="I_Field20"]/@value)[1]','nvarchar(60)'), I_Field20),       
      V_Max = ISNULL( Rw.value('(input[@id="V_Max"]/@value)[1]','nvarchar(max)'), V_Max),
      V_Barcode = ISNULL( Rw.value('(input[@id="V_Barcode"]/@value)[1]','nvarchar(max)'), V_Barcode)  
   FROM rdt.rdtMobRec r   
      JOIN @xInMessage.nodes('/fromRDT') AS A(Rw) ON (1=1)  
   WHERE Mobile = @nMobile  
  
  
  
   SET ANSI_NULLS OFF  
   SET ANSI_PADDING OFF  
   SET ANSI_WARNINGS OFF  
   -- SET ARITHABORT ON  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   -- SET NUMERIC_ROUNDABORT OFF  
   SET QUOTED_IDENTIFIER OFF  
END  
ELSE  
BEGIN   
   SET @cActionKey = 'NO'  -- ESC  
  
   -- For ESC, input field is not saved. This might change in future  
   UPDATE RDT.rdtMobRec WITH (ROWLOCK) SET   
      EditDate = GETDATE(),   
      InputKey = 0   
   WHERE Mobile = @nMobile  
END  

GO