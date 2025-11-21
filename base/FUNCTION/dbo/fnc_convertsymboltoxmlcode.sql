SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Function:  fnc_ConvertSymbolToXMLCode                                  */
/* Creation Date: 10-Dec-2010                                             */
/* Copyright: IDS                                                         */
/* Written by: Leong                                                      */
/*                                                                        */
/* Purpose:  Convert Symbol to XML Standard Code                          */
/*           XML Standard Symbol:                                         */
/*           (1) & - &amp;                                                */
/*           (2) < - &lt;                                                 */
/*           (3) > - &gt;                                                 */
/*           (4) " - &quot;                                               */
/*           (5) ' - &#39;                                                */
/*                                                                        */
/* Called By:  Any Stored Procedures.                                     */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 10-Dec-2010  Leong     1.0   SOS# 199159 - Create new function for XML */
/**************************************************************************/

CREATE FUNCTION [dbo].[fnc_ConvertSymbolToXMLCode] (@cString NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
   DECLARE @cOutString   NVARCHAR(1024),
           @nPosition    INT,
           @cChar        NVARCHAR(10),
           @cPrevChar    NVARCHAR(1),
           @nChineseChar INT,
           @nNoOfSpace   INT

   SET @nPosition = 1
   SET @cOutString = ''
   SET @cPrevChar = ''
   SET @nNoOfSpace = 0

   WHILE @nPosition <= LEN(@cString)
   BEGIN
      SET @cChar = SUBSTRING(@cString, @nPosition, 1)

      IF ASCII(@cChar) BETWEEN 0 AND 127
      BEGIN
         IF ASCII(@cChar) = 38 -- & (Ampersand)
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '&amp;')
            SET @cPrevChar = ''
         END

         IF ASCII(@cChar) = 60 -- < (Less than)
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '&lt;')
            SET @cPrevChar = ''
         END

         IF ASCII(@cChar) = 62 -- > (Greater than)
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '&gt;')
            SET @cPrevChar = ''
         END

         IF ASCII(@cChar) = 34 -- " (Double quote)
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '&quot;')
            SET @cPrevChar = ''
         END

         IF ASCII(@cChar) = 39 -- ' (Apostrophe)
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '&#39;')
            SET @cPrevChar = ''
         END

         -- IF ASCII(@cChar) = 13 OR ASCII(@cChar) = 10 OR ASCII(@cChar) = 9 -- Enter / Tab Key
         -- BEGIN
         --    SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), NULL)
         -- END

         IF ASCII(@cChar) = 32 -- Space
         BEGIN
            SET @nNoOfSpace = @nNoOfSpace + 1
         END
         ELSE
         BEGIN
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cChar
            SET @cPrevChar = ''
            SET @nNoOfSpace = 0
         END
      END

      SET @nPosition = @nPosition + 1
   END

   ReturnValue:
   RETURN (@cOutString)
END

GO