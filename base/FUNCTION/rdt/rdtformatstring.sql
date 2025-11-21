SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtFormatString    					                  */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Format float to string                                      */
/*                                                                      */
/* Date       Author    Ver   Purposes                                  */
/* 2015-01-22 Ung       1.0   SOS347332 Created                         */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtFormatString] (
   @cString NVARCHAR( MAX), 
   @nStart  INT, 
   @nLen    INT
) RETURNS NVARCHAR( MAX) AS
BEGIN
   DECLARE @i INT
   DECLARE @c NVARCHAR( 1)
   DECLARE @cReturn NVARCHAR( MAX)
   DECLARE @nActLen INT
   DECLARE @nActStart INT
   DECLARE @nStringLen INT
   DECLARE @nCharLen INT
   DECLARE @nCharWidth INT
   
   SET @i = 0
   SET @nActLen = 0
   SET @nActStart = 0
   SET @nStringLen = LEN( @cString)
   SET @cReturn = ''

   IF @cString IS NULL OR
      @nStart IS NULL OR
      @nLen IS NULL
      GOTO Quit

   IF @nStart < 1 OR @nLen < 1
      GOTO Quit

   -- Get rdt.NSQLConfig
   SET @nCharWidth = rdt.RDTGetConfig( 0, 'NonEnglishCharWidth', '')

   -- English env
   IF @nCharWidth <> 2
   BEGIN
      SET @cReturn = SUBSTRING( @cString, @nStart, @nLen)
      GOTO Quit
   END

   -- Loop each char in string
   WHILE @i < @nStringLen
   BEGIN
      SET @i = @i + 1
     
      -- Get the char
      SET @c = SUBSTRING( @cString, @i, 1) 
      
      -- Calc actual length need on screen
      IF UNICODE( @c) > 127
         SET @nCharLen = 2  -- Non english, occupy 2 chars width
      ELSE
         SET @nCharLen = 1  -- English, occupy 1 char width
         
      -- Keep track of actual start
      SET @nActStart = @nActStart + @nCharLen
      
      -- Add to output string
      IF @nActStart >= @nStart
      BEGIN
         -- Calc actual len on screen
         SET @nActLen = @nActLen + @nCharLen
      
         -- Exit condition
         IF @nActLen > @nLen
            BREAK

         SET @cReturn = @cReturn + @c
      END
   END
   
Quit:
   -- Return char that can fit on screen
   RETURN @cReturn
END

GO