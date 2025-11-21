SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_ConvSpecialCharToSpace                                */
/* Creation Date: 29-Jan-2013                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Convert Special Character to space.                         */
/*                                                                      */
/* Called By:  Any Stored Procedures.                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-Apr-2013  Leong     1.0   Replace ? symbol by space.              */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_ConvSpecialCharToSpace] (@cString NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
   DECLARE @cOutString   NVARCHAR(1024),
           @nPosition    INT,
           @cChar        NVARCHAR(1),
           @cPrevChar    NVARCHAR(1),
           @nNoOfSpace   INT,
           @nDblByteChar INT

   SET @nPosition = 1
   SET @cOutString = ''
   SET @cPrevChar = ''
   SET @nNoOfSpace = 0
   SET @nDblByteChar = 0 -- False

   /* ASCII Code:
      124 - |
       13 - Carrriage Return
       10 - Line Feed
        9 - Tab
   */

   WHILE @nPosition <= LEN(@cString)
   BEGIN
      SET @cChar = SUBSTRING(@cString, @nPosition, 1)

      IF ASCII(@cChar) BETWEEN 0 AND 127
      BEGIN
         IF ASCII(@cChar) = 124 -- |
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), ' ')
         END

         IF ASCII(@cChar) = 13 OR ASCII(@cChar) = 10 OR ASCII(@cChar) = 9 -- Enter / Tab
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), ' ')
         END

         IF @nDblByteChar = 1
         BEGIN
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar
            SET @cPrevChar = ''
            SET @nDblByteChar = 0
         END
         ELSE
         BEGIN
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
      END
      ELSE
      BEGIN
         IF @nDblByteChar = 0
         BEGIN
            SET @nDblByteChar = 1
            SET @cPrevChar = @cChar
         END
         ELSE
         BEGIN
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar
            SET @cPrevChar = ''
            SET @nNoOfSpace = 0
            SET @nDblByteChar = 0
         END
      END

      SET @nPosition = @nPosition + 1
   END

   ReturnValue:
   SET @cOutString = REPLACE(@cOutString, '?', '')
   RETURN (@cOutString)
END

GO