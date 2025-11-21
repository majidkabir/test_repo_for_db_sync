SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  fnc_ValidateDblByteChar                                   */
/* Creation Date: 27-Aug-09                                             */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose:  Remove Invalid double byte character.                      */
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
/* 25-02-2013   Leong     1.1   Replace NULL with Blank. (Leong01)      */
/* DD-MMM-YYYY                                                          */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_ValidateDblByteChar] (@cString NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	DECLARE @cOutString   NVARCHAR(1024),
           @nPosition    int,
           @cChar        NVARCHAR(1),
           @cPrevChar    NVARCHAR(1),
           @nChineseChar int,
           @nNoOfSpace   int

   SET @nPosition = 1
   SET @cOutString = ''
   SET @nChineseChar = 0 -- False
   SET @cPrevChar = ''
   SET @nNoOfSpace = 0

   /* ASCII Code:
      32 - Space
      13 - Carrriage Return
      10 - Line Feed
       9 - Tab
   */

   WHILE @nPosition <= LEN(@cString)
   BEGIN
      SET @cChar = SUBSTRING(@cString, @nPosition, 1)

      IF ASCII(@cChar) BETWEEN 0 AND 127
      BEGIN
         IF ASCII(@cChar) = 13 OR ASCII(@cChar) = 10 OR ASCII(@cChar) = 9
         BEGIN
            SET @cChar = REPLACE (ASCII(@cChar), ASCII(@cChar), '') -- Leong01
         END
         IF @nChineseChar = 1
         BEGIN
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar
            SET @cPrevChar = ''
            SET @nChineseChar = 0
         END
         ELSE
         BEGIN
            IF ASCII(@cChar) = 32
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
         IF @nChineseChar = 0
         BEGIN
            SET @nChineseChar = 1
            SET @cPrevChar = @cChar
         END
         ELSE
         BEGIN
            SET @cOutString = RTRIM(@cOutString) + REPLICATE(CHAR(32), @nNoOfSpace) + @cPrevChar + @cChar
            SET @cPrevChar = ''
            SET @nNoOfSpace = 0
            SET @nChineseChar = 0
         END
      END

      SET @nPosition = @nPosition + 1
   END

   ReturnValue:
	RETURN (@cOutString)
END

GO