SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCReceiveAudit_GetStat                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 10-Dec-2019  1.0  Chermaine   WMS-11357 - Created                          */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCReceiveAudit_GetStat] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 20),
   @cUCCNo        NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),  
   @nCQTY         INT OUTPUT, 
   @nPQTY         INT OUTPUT,
   @nTQTY         INT OUTPUT, 
   @cPosition     NVARCHAR ( 20)=NULL OUTPUT,  
   @nVariance     INT = NULL OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Get checked QTY Per SKU

SELECT 
   @nCQTY = ISNULL( SUM( CQty), 0)
FROM rdt.RDTReceiveAudit WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo
   AND sku = @cSKU
   
SELECT 
   @cPosition = Position
FROM rdt.RDTReceiveAudit WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo
   AND sku = @cSKU   


-- Get total QTY Per SKU
SELECT @nPQTY = ISNULL( SUM( QtyReceived), 0)
FROM RECEIPTDETAIL WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND ReceiptKey = @cReceiptKey
   AND UserDefine01 = @cUCCNo
   AND sku = @cSKU
      
-- Get total QTY 
SELECT @nTQTY = ISNULL( SUM( QTY), 0)
FROM UCC WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo

-- Get variance
SELECT 
   @nVariance = COUNT(*)
FROM rdt.RDTReceiveAudit WITH (NOLOCK)
WHERE StorerKey = @cStorerKey
   AND UCCNo = @cUCCNo
   AND ReceiptKey = @cReceiptKey
   AND CQty <> PQTY
   

GO