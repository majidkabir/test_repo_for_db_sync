SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE FUNCTION [RDT].[rdtGetParsedString] (
   @cInString    NVARCHAR( 256),        -- string to be parsed
   @nField       INT          = 1,  -- which field to return?
   @cDelimeter   NVARCHAR( 1)     = ',' -- delimeter
) RETURNS NVARCHAR( 256) AS
BEGIN

   -- Parameter checking
   IF @cInString IS NULL
      SET @cInString = ''
   IF @nField < 1
      SET @nField = 1
   IF @cDelimeter IS NULL OR @cDelimeter = ''
      SET @cDelimeter = ','

   DECLARE @cOutString NVARCHAR( 256)
   DECLARE @nStartPos INT
   DECLARE @nEndPos INT
   DECLARE @nLength INT
   DECLARE @nCount INT  -- Counter of field parsed

   SET @nStartPos = 1
   SET @nCount = 0
 
   WHILE CHARINDEX( @cDelimeter, @cInString, @nStartPos) > 0  
   BEGIN  
      SET @nEndPos = CHARINDEX( @cDelimeter, @cInString, @nStartPos)
      SET @nLength = @nEndPos - @nStartPos

      SET @nCount = @nCount + 1
      IF @nCount = @nField
         BREAK
      SET @nStartPos = @nEndPos + 1
   END  

   -- Got it. Parsed
   IF @nCount = @nField
      SET @cOutString = SUBSTRING(@cInString, @nStartPos, @nLength) 
   ELSE
      -- Cater for:
      -- 1. ('A' , 1, ',') = ''
      -- 2. (',B', 2, ',') = 'B'
      IF @nCount + 1 = @nField AND @nEndPos IS NOT NULL
         SET @cOutString = SUBSTRING(@cInString, @nStartPos, LEN( @cInString))  -- Trick. SUBSTRING( 'ABC', 2, 999) = 'BC'
      ELSE
         SET @cOutString = ''

   RETURN @cOutString

   /*
   SELECT RDT.rdtGetParsedString( '', 1, ',')

   Specification:
   (''  , 1, ',') = ''
   (',' , 1, ',') = ''
   (',' , 2, ',') = ''
   ('A' , 1, ',') = ''
   ('A,', 1, ',') = 'A'
   ('A,', 2, ',') = ''
   (',B', 2, ',') = 'B'
   
   ('A,B', 1, ',') = 'A'
   ('A,B', 2, ',') = 'B'
   ('A,B', 3, ',') = ''
   (',,', 1, ',') = ''
   (',,', 2, ',') = ''
   (',,', 3, ',') = ''
   
   ('', 1, '-') = ''
   ('A', 1, '-') = ''
   ('AB', 1, '-') = ''
   */
END

GO