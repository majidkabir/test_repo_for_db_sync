SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1825ExtInfo01                                   */
/*                                                                      */
/* Purpose: Display SKU category if mixed sku                           */
/*                                                                      */
/* Called from: rdtfnc_PreReceiveSort                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 12-Jun-2017 1.0  James      WMS1073 - Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1825ExtInfo01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 20), 
   @cLane            NVARCHAR( 10), 
   @cUCC             NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @cPosition        NVARCHAR( 20),   
   @cRecordCount     NVARCHAR( 20),   
   @cExtendedInfo    NVARCHAR( 20)  OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                     WHERE ListName = 'PreRcvLane'
                     AND   StorerKey = @cStorerKey
                     AND   Code = '003'
                     AND   [Description] = @cPosition)
         BEGIN
            SELECT TOP 1 @cExtendedInfo = SKU.BUSR7
            FROM dbo.UCC UCC WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON 
               ( UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
            WHERE UCC.UCCNo = @cUCC
         END

      END
   END

   Quit:

SET QUOTED_IDENTIFIER OFF

GO