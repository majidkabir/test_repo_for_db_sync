SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: rdtGetXML_V1                                           */
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
/* 24-Dec-2010  1.5   Shong     Remove Scn from Display (Shong01)           */
/* 07-Jun-2011  1.6   ChewKP    Display Mobile in 4 digit (ChewKP01)        */
/****************************************************************************/

CREATE PROC [RDT].[rdtGetXML_V1](
   @nMobile INT, 
   @cXML NVARCHAR(4000) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTyp     NVARCHAR(125),
           @cX       NVARCHAR(10),
           @cY       NVARCHAR(10),
           @cLength  NVARCHAR(10),
           @cID      NVARCHAR(20),
           @cDefault NVARCHAR(60),
           @cType    NVARCHAR(20),
           @cValue   NVARCHAR(125),
           @cFocus   NVARCHAR(20),
           @cErrMsg  NVARCHAR(125)
   
   -- (Vicky02) - Start
   DECLARE @cUsername   NVARCHAR(15),
           @cMobileDisp NVARCHAR(1)  
   
   SELECT @cUsername = RTRIM(UserName), @cErrMsg = RTRIM(ErrMSG)
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile
   
   SELECT @cMobileDisp = ISNULL(MobileNo_Display, 'Y')
   FROM RDT.RDTUSER (NOLOCK)
   WHERE Username = @cUsername
   -- (Vicky02) - End

   

   -- SELECT @nMobile = 1
   SELECT @cXML = '<?xml version="1.0" encoding="UTF-16"?>'

   SET    @cFocus = NULL
   SELECT @cFocus = Focus FROM RDT.RDTXML_Root (NOLOCK) WHERE Mobile = @nMobile



   IF RTRIM(@cFocus) IS NOT NULL AND RTRIM(@cFocus) <> ''
   BEGIN
        IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg)<>''
        BEGIN
           SET @cXML = RTRIM(@cXML) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) )
            + '" focus="' + RTRIM(@cFocus) + '" status=''error''>'
        END
        ELSE
        BEGIN
            SET @cXML = RTRIM(@cXML) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) )
            + '" focus="' + RTRIM(@cFocus) + '">'
        END
   END
   ELSE IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg)<>''
	BEGIN
		  SET @cXML = RTRIM(@cXML) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) ) + '" status=''error''>'
	END
   ELSE
   BEGIN
        SET @cXML = RTRIM(@cXML) + ' <tordt number="' + RTRIM( CAST(@nMobile as NVARCHAR(10)) ) + '">'
   END 

   DECLARE XML_Cur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT typ,
          x,
          y,
          length,
          [id],
          [default],
          type,
          value
   FROM RDT.[RDTXML_Elm] (NOLOCK)
   WHERE mobile = @nMobile
   Order by y, x

   OPEN XML_Cur

   FETCH NEXT FROM XML_Cur INTO @cTyp, @cX, @cY, @cLength, @cID, @cDefault, @cType, @cValue

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @cXML = RTRIM(@cXML) + '<field'
      IF RTRIM(@cTyp) IS NOT NULL
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' typ="' + RTRIM(@cTyp) + '"'
      END
      IF RTRIM(@cX) IS NOT NULL
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' x="' + RTRIM(@cX) + '"'
      END
      IF RTRIM(@cY) IS NOT NULL
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' y="' + RTRIM(@cY) + '"'
      END
      IF RTRIM(@cLength) IS NOT NULL AND RTRIM(@cLength) <> '0'
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' length="' + RTRIM(@cLength) + '"'
      END
      IF RTRIM(@cID) IS NOT NULL
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' id="' + RTRIM(@cID) + '"'
      END


      IF RTRIM(@cDefault) IS NOT NULL
      BEGIN
         SET @cDefault = RDT.rdtReplaceSpecialCharInXMLData( @cDefault)
         SET @cXML     = RTRIM(@cXML) + ' default="' + RTRIM(@cDefault) + '"'
      END
      IF RTRIM(@cType) IS NOT NULL
      BEGIN
           SET @cXML = RTRIM(@cXML) + ' type="' + RTRIM(@cType) + '"'
      END

      IF RTRIM(@cValue) IS NOT NULL
      BEGIN
         SET @cValue = RDT.rdtReplaceSpecialCharInXMLData( @cValue)
         SET @cXML   = RTRIM(@cXML) + ' value="' + RTRIM(@cValue) + '"' -- Add RTRIM (Vicky01)
      END

      SET @cXML = RTRIM(@cXML) + '/>'

      IF RTRIM(@cTyp) IS NOT NULL
      BEGIN
           FETCH NEXT FROM XML_Cur INTO @cTyp, @cX, @cY, @cLength, @cID, @cDefault, @cType, @cValue
      END
   END

   CLOSE XML_Cur
   DEALLOCATE XML_Cur

   DECLARE @nFunc int,
           @nStep int,
           @nScn  int

   SET ROWCOUNT 1

   SELECT @nFunc = [Func],
          @nStep = [Step],
          @nScn  = [Scn]
   FROM   RDT.RDTMOBREC (NOLOCK)
   WHERE  Mobile = @nMobile

   SET ROWCOUNT 0

   -- (Vicky02) - Start
   IF @cMobileDisp = 'N'
   BEGIN
	   SET @cXML = RTRIM(@cXML) + 
       '<field typ="output" x="01" y="15" value="Fn'+ RTRIM(CAST(@nFunc as NVARCHAR(4)))  
       -- + '-Sn' + RTRIM(CAST(@nScn as NVARCHAR(3)))  -- (Shong01)
       + '-St' + RTRIM(CAST(@nStep as NVARCHAR(3)))    
	    -- + '-M' + RTRIM(CAST(@nMobile as NVARCHAR(3)))  -- take out because screen only can display 19 chars
	   +  '"/>'
   END
   ELSE
   -- (Vicky02) - End
   BEGIN
       SET @cXML = RTRIM(@cXML) + 
       '<field typ="output" x="01" y="15" value="Fn'+ RTRIM(CAST(@nFunc as NVARCHAR(4)))  
       -- + '-Sn' + RTRIM(CAST(@nScn as NVARCHAR(3)))  -- (Shong01)
       + '-St' + RTRIM(CAST(@nStep as NVARCHAR(3)))    
       + '-M'  + RTRIM(CAST(@nMobile as NVARCHAR(4))) -- (ChewKP01)
       +  '"/>'
   END

   SET @cXML = RTRIM(@cXML) +'</tordt>'

GO