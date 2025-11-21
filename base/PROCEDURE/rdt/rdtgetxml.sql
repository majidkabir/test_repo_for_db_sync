SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: rdtGetXML                                              */
/* Creation Date: 19-Dec-2004                                               */
/* Copyright: IDS                                                           */
/* Written by: Shong                                                        */
/*                                                                          */
/* Purpose: Generate the XML output from the formated records from the      */
/*          temporary table                                                 */
/*                                                                          */
/* Input Parameters: Mobile No                                              */
/*                                                                          */
/* Output Parameters: XML result set                                        */
/*                                                                          */
/* Return Status:                                                           */
/*                                                                          */
/* Usage:                                                                   */
/*                                                                          */
/*                                                                          */
/* Called By: rdtHandle                                                     */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Ver.  Author    Purposes                                    */
/* 17-Nov-2008  1.3   Vicky     Trim the empty value (Vicky01)              */
/* 23-Feb-2009  1.4   Vicky     Check whether need to display MobileNo for  */
/*                              user login.This is to suit IDSUK            */
/*                              WWC series Handheld, which only has 6 row   */
/*                              (Vicky02)                                   */
/* 24-NOV-2009        ChewKP    Changes For RDT2 Column Attributes (ChewKP01)*/
/* 24-Dec-2010  1.5   Shong     Remove Scn from Display (Shong01)           */
/* 07-Jun-2011  1.6   ChewKP    Display Mobile in 4 digit (ChewKP02)        */
/* 18-Sep-2013  1.7   ChewKP    Add new features RemotePrint (ChewKP03)     */
/* 22-Nov-2014  1.8   Shong     Bug fixed                                   */
/* 02-Oct-2015  1.9   Ung       Performance tuning for CN Nov 11            */
/* 15-aug-2016  2.0   Ung       Update rdtMobRec with EditDate              */
/****************************************************************************/

CREATE PROC [RDT].[rdtGetXML](
   @nMobile INT, 
   @cXML NVARCHAR(MAX) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @cTyp     NVARCHAR(125),
           @cX       NVARCHAR(10),
           @cY       NVARCHAR(10),
           @cLength  NVARCHAR(10),
           @cID      NVARCHAR(20),
           @cDefault NVARCHAR(60),
           @cType    NVARCHAR(20),
           @cValue   NVARCHAR(125),
           @cFocus   NVARCHAR(20),
           @c_listvalue NVARCHAR(20),
           @c_textcolor NVARCHAR(50),
           @c_match  NVARCHAR(50),
			  @cErrMsg  NVARCHAR(125),
			  @cV_MAX   NVARCHAR(MAX),        -- (ChewKP03)
			  @nRemotePrint INT,              -- (ChewKP03)
			  @c_StringEncoding NVARCHAR(10), -- (ChewKP03)
			  @cPrintData   NVARCHAR(MAX),    -- (ChewKP03)
           @cXMLHeader   NVARCHAR(200), 
           @cXMLFooter   NVARCHAR(100)
   
   -- (Vicky02) - Start
   DECLARE @cUsername   NVARCHAR(15),
           @cMobileDisp NVARCHAR(1)  
   
   SELECT @cUsername = RTRIM(UserName) , @cErrMsg = RTRIM(ErrMSG)
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile
   
   SELECT @cMobileDisp = ISNULL(MobileNo_Display, 'Y')
   FROM RDT.RDTUSER (NOLOCK)
   WHERE Username = @cUsername
   -- (Vicky02) - End

   -- SELECT @nMobile = 1
   SELECT @cXMLHeader = '<?xml version="1.0" encoding="UTF-8"?>' 

   SET    @cFocus = NULL
   SELECT @cFocus = Focus FROM RDT.RDTXML_Root (NOLOCK) WHERE Mobile = @nMobile

   IF RTRIM(@cFocus) IS NOT NULL AND RTRIM(@cFocus) <> ''
   BEGIN
        IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg)<>''
        BEGIN
           SET @cXMLHeader = RTRIM(@cXMLHeader) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) )
            + '" focus="' + RTRIM(@cFocus) + '" status="error">'
        END
        ELSE
        BEGIN
            SET @cXMLHeader = RTRIM(@cXMLHeader) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) )
            + '" focus="' + RTRIM(@cFocus) + '">'
        END
   END
   ELSE IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg)<>''
	BEGIN
		  SET @cXMLHeader = RTRIM(@cXMLHeader) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) ) + '" status="error">'
	END
	ELSE
   BEGIN
        SET @cXMLHeader = RTRIM(@cXMLHeader) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) ) + '" >'
   END 


   DECLARE @nFunc int,
           @nStep int,
           @nScn  int

   SELECT @nFunc = [Func],
          @nStep = [Step],
          @nScn  = [Scn],
          @nRemotePrint = RemotePrint,
          @cV_MAX = V_MAX
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile

   -- (ChewKP03)
   -- When RemotePrint = 1 , generate xml print node
   IF @nRemotePrint = 1
   BEGIN
      SET @c_StringEncoding = 'utf-8'
      SET @cPrintData = ''
      
      EXEC master.dbo.isp_Base64Encode
         @c_StringEncoding    ,
         @cV_MAX      ,
         @cPrintData       OUTPUT,
         @cErrMsg          OUTPUT
       
      SET @cXML = RTRIM(@cXML) + '<field typ="print">' + @cPrintData + '</field>' 
      
      -- Reset Remote Print
      UPDATE rdt.rdtMobrec WITH (ROWLOCK) SET 
         EditDate = GETDATE(), 
         RemotePrint = 0, 
         V_MAX = ''
      WHERE Mobile = @nMobile
      
   END

   -- (Vicky02) - Start
   IF @cMobileDisp = 'N'
   BEGIN
	   SET @cXMLFooter = 
	   '<field typ="output" x="01" y="6" value="Fn'+ RTRIM(CAST(@nFunc as NVARCHAR(4))) 
	   --+ '-Sn' + RTRIM(CAST(@nScn as NVARCHAR(3))) (Shong01)
	   + '-St' + RTRIM(CAST(@nStep as NVARCHAR(3))) 
	  -- + '-M' + RTRIM(CAST(@nMobile as NVARCHAR(3)))  -- take out because screen only can display 19 chars
	   +  '"/>'
   END
   ELSE
   -- (Vicky02) - End
   BEGIN
       SET @cXMLFooter = 
       '<field typ="output" x="01" y="15" value="Fn'+ RTRIM(CAST(@nFunc as NVARCHAR(4))) 
       --+ '-Sn' + RTRIM(CAST(@nScn as NVARCHAR(3))) (Shong01)
       + '-St' + RTRIM(CAST(@nStep as NVARCHAR(3))) 
       + '-M' + RTRIM(CAST(@nMobile as NVARCHAR(5))) -- (ChewKP02)
       +  '"/>'
   END
   SET @cXMLFooter = @cXMLFooter +'</tordt>'

   SET @cXML = @cXMLHeader + @cXML + @cXMLFooter


GO