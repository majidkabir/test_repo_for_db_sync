SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtReplaceSpecialCharInXMLData    					   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Replace the 5 special characters in XML data to their       */
/*          translated presentation. If not, XML parser will fail       */
/*                                                                      */
/*          & --> &amp;                                                 */
/*          < --> &lt;                                                  */
/*          > --> &gt;                                                  */
/*          " --> &quot;                                                */
/*          ' --> &apos;                                                */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Rev  Author     Purposes                                */
/* 2006-02-15   1.0  dhung      Created                                 */
/* 2009-11-06   1.1  Vicky      Revamp checking of special Char         */
/*                              (Vicky01)                               */
/* 2014-12-02   1.2  Ung        Fix SET option                          */
/* 2015-10-05   1.3  Ung        Performance tuning                      */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtReplaceSpecialCharInXMLData] (
   @cXML NVARCHAR( 4000)
) RETURNS NVARCHAR( 4000) AS
BEGIN
   -- SET NOCOUNT ON                   -- Cannot compile in function
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   -- SET CONCAT_NULL_YIELDS_NULL OFF  -- Cannot compile in function
   
   -- Parameter checking
   IF @cXML IS NULL OR @cXML = ''
      GOTO Fail

   -- Substitute special chars in XML data
   IF CHARINDEX( '&', @cXML) > 0
   BEGIN
      SET @cXML = REPLACE( @cXML, '&', '&amp;')
   END

   IF CHARINDEX( '<',@cXML) > 0
   BEGIN
      SET @cXML = REPLACE( @cXML, '<', '&lt;')
   END

   IF CHARINDEX('>',@cXML) > 0
   BEGIN
      SET @cXML = REPLACE( @cXML, '>', '&gt;')
   END

   IF CHARINDEX('"',@cXML) > 0
   BEGIN
      SET @cXML = REPLACE( @cXML, '"', '&quot;')
   END  

   IF CHARINDEX('''',@cXML) > 0
   BEGIN
      SET @cXML = REPLACE( @cXML, '''', '&apos;')
   END  
   GOTO Quit
   
Fail:
   RETURN ''
Quit:
   RETURN @cXML
END


GO