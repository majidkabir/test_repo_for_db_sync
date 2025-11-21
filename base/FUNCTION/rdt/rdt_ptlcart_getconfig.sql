SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_GetConfig                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 22-03-2022 1.0  Ung         WMS-18742 Created                        */
/************************************************************************/

CREATE   FUNCTION [RDT].[rdt_PTLCart_GetConfig] (
   @nFunc      INT, 
   @cConfigKey NVARCHAR( 30), 
   @cStorerKey NVARCHAR( 15),
   @cMethod    NVARCHAR( 1)
) RETURNS NVARCHAR( 20) AS
BEGIN
   DECLARE @cCR      NCHAR(1) = NCHAR(13) -- Carriage return
   DECLARE @cLF      NCHAR(1) = NCHAR(10) -- Line feed
   DECLARE @cNotes   NVARCHAR( 4000)
   DECLARE @cSValue  NVARCHAR( 20)
   
   -- Get method info
   SELECT @cNotes = ISNULL( Notes, '')
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CARTMETHOD' 
      AND StorerKey = @cStorerKey
      AND Code = @cMethod
   
   -- Replace CR with LF (due to STRING_SPLIT only accept 1 char delimeter)
   SET @cNotes = REPLACE( @cNotes, @cCR, '')
   
   -- Abstract config
   SELECT 
      -- @cConfigKey = SUBSTRING( Value, 1, CHARINDEX( '=', Value) - 1), 
      @cSValue = SUBSTRING( Value, CHARINDEX( '=', Value) + 1, LEN( Value))
   FROM STRING_SPLIT( @cNotes, @cLF)
   WHERE CHARINDEX( '=', Value) > 0 -- Filter out lines without delimeter
      AND TRIM( SUBSTRING( Value, 1, CHARINDEX( '=', Value) - 1)) = @cConfigKey

   IF @@ROWCOUNT = 0
      SET @cSValue = rdt.rdtGetConfig( @nFunc, @cConfigKey, @cStorerKey)
   ELSE
      SET @cSValue = ISNULL( @cSValue, '0')
   
   RETURN @cSValue
END

GO