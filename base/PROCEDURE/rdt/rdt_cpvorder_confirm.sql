SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_CPVOrder_Confirm                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 11-06-2018 1.0  Ung       WMS-5368 Created                           */  
/* 11-03-2019 1.1  CheWKP    Fixes                                      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CPVOrder_Confirm] (  
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
   @cLottable07   NVARCHAR( 30) = '',   
   @cLottable08   NVARCHAR( 30) = '',   
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
     
   SET @nTranCount = @@TRANCOUNT  
  
   -- Get scan QTY again, due to multi user  
   SELECT @nScan = ISNULL( SUM( QTY), 0)  
   FROM rdt.rdtCPVOrderLog WITH (NOLOCK)  
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
   IF @nScan + @nInnerPack > @nTotal  
   BEGIN  
      SET @nErrNo = 125051  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fully scanned  
      GOTO Quit  
   END  
  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdtfnc_Confirm -- For rollback or commit only our own transaction  
   
   INSERT INTO rdt.rdtCPVOrderLog   
      (Mobile, OrderKey, StorerKey, SKU, QTY, Barcode, Lottable07, Lottable08)  
   VALUES  
      (@nMobile, @cOrderKey, @cStorerKey, @cSKU, @nInnerPack, @cBarcode, @cLottable07, @cLottable08)  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 125052  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail  
      GOTO RollbackTran  
   END  
  
   COMMIT TRAN rdtfnc_Confirm -- Only commit change made here  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
        
   -- Get scan QTY  
   SELECT @nScan = ISNULL( SUM( QTY), 0)  
   FROM rdt.rdtCPVOrderLog WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  
      AND SKU = @cSKU  
  
   -- Get total QTY  
   SELECT @nTotal = ISNULL(( SUM( OD.OpenQTY) - SUM(QtyAllocated)), 0)  
   FROM dbo.Orders O WITH (NOLOCK)  
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey AND O.StorerKey = OD.StorerKey)  
   WHERE O.OrderKey = @cOrderKey  
      AND O.StorerKey = @cStorerKey  
      AND OD.SKU = @cSKU  
  
   -- Convert to inner pack  
   SET @cScan = @nScan / @nInnerPack  
   SET @cTotal = @nTotal / @nInnerPack  
     
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdtfnc_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  


GO