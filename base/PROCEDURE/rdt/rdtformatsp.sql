SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   PROC [RDT].[rdtFormatSP] (
   @nRowRef    INT = 0,
   @cObjText   NVARCHAR( MAX) = ''
) AS 
BEGIN
   IF @nRowRef > 0
      SELECT @cObjText = TSQL FROM DBStatusTrack WITH (NOLOCK) WHERE @nRowRef = RowRef
   
   IF @cObjText <> ''
   BEGIN
      /*
         --https://dba.stackexchange.com/a/175766/60085
         STRING_SPLIT only accept 1 char delimeter, so cannot split line base on CRLF (2 chars)
         replace CRLF in the string, with a rare char
         replace LF   in the string, with a rare char
         then use STRING_SPLIT to split line, base on the rare char
      */
      DECLARE @cCRLF     NCHAR(2) = CHAR(13) + CHAR(10)
      DECLARE @cLF       NCHAR(1) = CHAR(10)
      DECLARE @cRareChar NCHAR(1) = NCHAR(9999) -- an unicode char (the author use the pencil char)

      SELECT value
      FROM STRING_SPLIT( REPLACE( REPLACE( @cObjText,@cCRLF, @cRareChar), @cLF, @cRareChar), @cRareChar)
   END
END

GO