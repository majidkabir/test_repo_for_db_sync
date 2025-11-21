SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtRightAlign    					                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Right align string                                          */
/*                                                                      */
/* Date       Author    Ver   Purposes                                  */
/* 2015-06-10 Ung       1.0   SOS315262 Created                         */
/************************************************************************/
CREATE FUNCTION rdt.rdtRightAlign (
   @cString NVARCHAR( MAX), 
   @nLength INT
) RETURNS NVARCHAR( MAX) AS
BEGIN
   -- Check invalid length
   IF @nLength < 1
      GOTO Fail

   -- Check invalid string
   IF @cString IS NULL
      GOTO Fail

   -- Get string length
   DECLARE @nStringLen INT
   SET @nStringLen = LEN( @cString)
   
   -- Check empty string
   IF @nStringLen = 0
      GOTO Fail

   -- Calc space required
   DECLARE @nSpace INT
   IF @nStringLen < @nLength
      SET @nSpace =  @nLength - @nStringLen
   ELSE
      SET @nSpace = 0
   
   GOTO Quit

Fail:
   RETURN ''
Quit:
   -- Note: RIGHT() is not working with NVARCHAR( MAX)
   RETURN SPACE( @nSpace) + SUBSTRING( @cString, 1, @nLength-@nSpace)
END

GO