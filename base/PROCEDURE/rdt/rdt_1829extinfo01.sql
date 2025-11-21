SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtInfo01                                         */
/* Purpose: Display total count of asn in receiptgroup                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Jul-19 1.0  James    WMS2289 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtInfo01] (
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

   DECLARE @nCount              INT
   DECLARE @cReceiptGroup       NVARCHAR( 20)

   SET @cReceiptGroup = @cParam1

   IF @nStep IN ( 1, 3)
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @nCount = 0
         SELECT @nCount = COUNT( 1)
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptGroup = @cReceiptGroup
         AND   [Status] < '9' 
         AND   ASNStatus <> 'CANC'

         SET @cExtendedInfo1 = 'TOTAL ASN:' + CAST( @nCount AS NVARCHAR( 5))
      END   -- ENTER
   END   

Quit:



GO