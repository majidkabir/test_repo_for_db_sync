SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal01                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2016-01-04 1.0  Ung     SOS358802 Created                               */
/* 2018-04-05 1.1  Ung     WMS-4488 Add pallet cannot mix L01              */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal01]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      DECLARE @nTranCount     INT
      DECLARE @cStorerKey     NVARCHAR(15)
      DECLARE @cSKU           NVARCHAR(20)
      DECLARE @cCartonGroup   NVARCHAR(10)
      DECLARE @cIOFlag        NVARCHAR(1)
      DECLARE @cBUSR3         NVARCHAR(30)
      DECLARE @cStyle         NVARCHAR(20)
      DECLARE @cSize          NVARCHAR(10)
      DECLARE @cUDF01         NVARCHAR(15)
      DECLARE @fSTDGrossWGT   FLOAT
      DECLARE @fSTDNetWGT     FLOAT
      DECLARE @cCubicScan     NVARCHAR(1)
      DECLARE @cChkLottable01 NVARCHAR(18)
      
      -- Get StorerKey
      SELECT @cStorerKey = StorerKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
      
      -- Get current UCC is single/multi SKU
      DECLARE @nSKUCount INT
      SET @nSKUCount = 0
      SELECT @nSKUCount = COUNT(1) 
      FROM UCC WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
      WHERE UCC.StorerKey = @cStorerKey
         AND UCC.UCCNo = @cUCC
         
      -- Check single UCC mix on multi SKU UCC pallet
      IF @nSKUCount = 1
      BEGIN
         IF EXISTS( SELECT 1
            FROM UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND ID = @cToID
            GROUP BY UCCNo
            HAVING COUNT( DISTINCT SKU) > 1)
         BEGIN
            SET @nErrNo = 59301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix Multi UCC
            GOTO Quit
         END
      END

      -- Check multi SKU UCC mix on single SKU UCC pallet
      IF @nSKUCount > 1
      BEGIN
         IF EXISTS( SELECT 1
            FROM UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND ID = @cToID
            GROUP BY UCCNo
            HAVING COUNT( DISTINCT SKU) = 1)
         BEGIN
            SET @nErrNo = 59302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix Single UCC
            GOTO Quit
         END
      END
      
      -- Get UCC info
      SELECT 
         @cSKU = SKU, 
         @cUDF01 = UserDefined01
      FROM UCC WITH (NOLOCK) 
      WHERE UCC.StorerKey = @cStorerKey 
         AND UCC.UCCNo = @cUCC
      
      -- UCC need cubic scan
      IF @cUDF01 = '1'
      BEGIN
         -- Get SKU info
         SELECT 
            @cCartonGroup = CartonGroup, 
            @cIOFlag = ISNULL( IOFlag, ''), 
            @cBUSR3 = ISNULL( BUSR3, ''), 
            @cStyle = Style, 
            @cSize = Size,   
            @fSTDGrossWGT = STDGrossWGT, 
            @fSTDNetWGT = STDNetWGT
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         -- SKU not yet catch weight 
         IF (@cIOFlag <> '1' OR @fSTDGrossWGT = 0 OR @fSTDNetWGT = 0) AND  -- SKU not yet catch weight
            @cCartonGroup IN ('GOH', 'ECOM/FP', 'OTHERS')                  -- SKU group need to catch weight
         BEGIN
            IF @cCartonGroup = 'GOH' OR @cCartonGroup = 'ECOM/FP'
               IF NOT EXISTS( SELECT 1 
                  FROM rdt.rdtCarterCubicGroupLog WITH (NOLOCK) 
                  WHERE CartonGroup = @cCartonGroup 
                     AND BUSR3 = @cBUSR3
                     AND Style = @cStyle
                     AND Size = @cSize)
                  SET @cCubicScan = 'Y'
                        
            IF @cCartonGroup = 'OTHERS'
               SET @cCubicScan = 'Y'
                        
            IF @cCubicScan = 'Y'
            BEGIN
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_898UCCExtVal01 -- For rollback or commit only our own transaction
               
               IF @cCartonGroup = 'GOH' OR @cCartonGroup = 'ECOM/FP'
               BEGIN
                  -- Mark entire group catch weight
                  INSERT INTO rdt.rdtCarterCubicGroupLog (CartonGroup, BUSR3, Style, Size) 
                  VALUES (@cCartonGroup, @cBUSR3, @cStyle, @cSize)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 59303
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
                     GOTO RollBackTran
                  END
               END
            
               -- Mark as cubed
               UPDATE SKU SET
                  IOFlag = '1'
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 59304
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
                  GOTO RollBackTran
               END
      
               -- Prompt for cubic scan
               SET @nErrNo = 59305
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CubicScan
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg
               SET @nErrNo = 0
               
               COMMIT TRAN rdt_898UCCExtVal01
            END
         END
      END
      
      -- Get pallet L01
      SELECT TOP 1 
         @cChkLottable01 = Lottable01
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cToID
         AND BeforeReceivedQTY > 0

      -- Check pallet mix L01
      IF @@ROWCOUNT > 0
      BEGIN
         IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND UserDefine01 = @cUCC AND Lottable01 <> @cChkLottable01)
         BEGIN
            SET @nErrNo = 59306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mix L01
            GOTO Quit
         END
      END
   END
   
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_898UCCExtVal01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO