SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593Print11Decode                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-06-06 1.0  Ung      WMS-1911 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print11Decode] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15), 
   @cLabelPrinter  NVARCHAR( 15), 
   @cBarcodePart1  NVARCHAR( 20)  OUTPUT,
   @cBarcodePart2  NVARCHAR( 20)  OUTPUT,
   @cBarcodePart3  NVARCHAR( 20)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @c        NVARCHAR( 1)
   DECLARE @cBracket NVARCHAR(10)
   DECLARE @cBarcode NVARCHAR(20)
   DECLARE @i        INT
   DECLARE @j        INT
   DECLARE @iLen     INT
   
   SET @j = 1
   WHILE @j <= 3
   BEGIN
      IF @j = 1 SET @cBarcode = @cBarcodePart1 ELSE
      IF @j = 2 SET @cBarcode = @cBarcodePart2 ELSE
      IF @j = 3 SET @cBarcode = @cBarcodePart3 
   
      SET @iLen = LEN( @cBarcode)
      SET @i = 1 
      SET @cBracket = 'OPEN'
   
      WHILE @i <= @iLen
      BEGIN
         SET @c = SUBSTRING( @cBarcode, @i, 1)
         IF @c = '.'
         BEGIN
            IF @cBracket = 'OPEN'
            BEGIN
               SET @cBarcode = STUFF( @cBarcode, @i, 1, '(')
               SET @cBracket = 'CLOSE'
            END
            ELSE
            BEGIN
               SET @cBarcode = STUFF( @cBarcode, @i, 1, ')')
               SET @cBracket = 'OPEN'
            END
         END
         SET @i = @i + 1
      END

      IF @j = 1 SET @cBarcodePart1 = @cBarcode ELSE
      IF @j = 2 SET @cBarcodePart2 = @cBarcode ELSE
      IF @j = 3 SET @cBarcodePart3 = @cBarcode 
      
      SET @j = @j + 1
   END

Quit:


GO