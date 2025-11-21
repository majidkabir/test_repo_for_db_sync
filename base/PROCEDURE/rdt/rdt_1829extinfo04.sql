SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtInfo04                                         */
/* Purpose: Display total Qty scanned/ total ASN qty                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-Feb-26 1.0  James    WMS8010 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtInfo04] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nQtyinLoc      INT
   DECLARE @nQtyinRD       INT
   DECLARE @cReceiptKey    NVARCHAR( 10)

   SET @cReceiptKey = @cParam1
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nQtyinLoc = ISNULL( SUM( Qty), 0)
         FROM rdt.rdtPreReceiveSort2Log WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cParam1
         AND   SKU = @cUCCNo
         AND   [Status] = '1'

         SELECT @nQtyinRD = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cParam1
         AND   SKU = @cUCCNo

         SET @cExtendedInfo1 = 'Qty SCANNED:' + RTRIM( CAST( @nQtyinLoc AS NVARCHAR( 5))) + '/' + RTRIM( CAST( @nQtyinRD AS NVARCHAR( 5)))
      END   -- ENTER
   END   

Quit:



GO