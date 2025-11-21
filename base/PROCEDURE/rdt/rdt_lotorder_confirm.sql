SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_LotOrder_Confirm                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 23-Mar-2023 1.0  yeekung   WMS-21873 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_LotOrder_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cOrderKey     NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nInnerPack    INT,
   @cBarcode      NVARCHAR( 60) = '',
   @cLottable01   NVARCHAR( 18) = '', 
   @cLottable02   NVARCHAR( 18) = '', 
   @cLottable03   NVARCHAR( 18) = '', 
   @dLottable04   DATETIME      = '', 
   @dLottable05   DATETIME      = '', 
   @cLottable06   NVARCHAR( 30) = '', 
   @cLottable07   NVARCHAR( 30) = '', 
   @cLottable08   NVARCHAR( 30) = '', 
   @cLottable09   NVARCHAR( 30) = '', 
   @cLottable10   NVARCHAR( 30) = '', 
   @cLottable11   NVARCHAR( 30) = '', 
   @cLottable12   NVARCHAR( 30) = '', 
   @dLottable13   DATETIME      = '', 
   @dLottable14   DATETIME      = '', 
   @dLottable15   DATETIME      = '', 
   @cScan         NVARCHAR( 10) = '' OUTPUT,
   @cTotal        NVARCHAR( 10) = '' OUTPUT,
   @nErrNo        INT           = 0  OUTPUT,
   @cErrMsg       NVARCHAR( 20) = '' OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @nTotal      INT
   DECLARE @nScan       INT
   DECLARE @cShelflife  INT


   SET @nTranCount = @@TRANCOUNT


   -- Get scan QTY again, due to multi user
   SELECT @nScan = ISNULL( SUM( QTY), 0) 
   FROM rdt.rdtLotOrderLog WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
      AND SKU = @cSKU

   -- Get total QTY
   SELECT @nTotal = ISNULL( (SUM( OD.OpenQTY) - SUM(QtyAllocated)), 0)
   FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey AND O.StorerKey = OD.StorerKey)
   WHERE O.OrderKey = @cOrderKey
      AND O.StorerKey = @cStorerKey
      AND OD.SKU = @cSKU

   -- Check balance
   IF @nScan  >= @nTotal
   BEGIN
      SET @nErrNo = 198551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fully scanned
      GOTO Quit
   END

   SET @nScan = @nScan + 1

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_LotOrder_Confirm -- For rollback or commit only our own transaction

   IF NOT EXISTS (SELECT 1 FROM rdt.rdtLotOrderLog (NOLOCK) 
               WHERE ORDERKEY = @cOrderKey
                  AND Storerkey = @cStorerKey
                  AND Lottable07 = @cLottable07
                  AND SKU = @cSKU)
   BEGIN
      IF ISNULL(@cBarcode,'')=''
      BEGIN
         SET @cLottable03 =  ''
         SET @dLottable04 =  ''
         SET @dLottable05 =  ''
      END

      SET @cLottable12 =  ''

      INSERT INTO rdt.rdtLotOrderLog
         (Mobile, OrderKey, StorerKey, SKU, QTY, Barcode,Lottable01,Lottable02,Lottable03,Lottable04, Lottable05,
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,Lottable11, Lottable12, Lottable13, Lottable14)
      VALUES
         (@nMobile, @cOrderKey, @cStorerKey, @cSKU, 1, @cBarcode,@cLottable01,@cLottable02,@cLottable03,@dLottable04, @dLottable05,
         @cLottable06, @cBarcode, @cLottable08, @cLottable09, @cLottable10,@cLottable11, @cLottable12, @dLottable13, @dLottable14)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail
         GOTO RollbackTran
      END
   END
   ELSE
   BEGIN
      UPDATE rdt.rdtLotOrderLog
      SET QTY = QTY + 1
      WHERE ORDERKEY = @cOrderKey
         AND Storerkey = @cStorerKey
         AND Lottable07 = @cLottable07
         AND SKU = @cSKU
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail
         GOTO RollbackTran
      END
   END

   -- Get total QTY
   SELECT @nTotal = ISNULL(( SUM( OD.OpenQTY) - SUM(QtyAllocated)), 0)
   FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey AND O.StorerKey = OD.StorerKey)
   WHERE O.OrderKey = @cOrderKey
      AND O.StorerKey = @cStorerKey
      AND OD.SKU = @cSKU


   -- Convert to inner pack   
   SET @cScan = @nScan 
   SET @cTotal = @nTotal 

   COMMIT TRAN rdt_LotOrder_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN  rdt_LotOrder_Confirm-- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO