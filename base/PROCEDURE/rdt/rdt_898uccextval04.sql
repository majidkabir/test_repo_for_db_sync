SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal04                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-01-19 1.0  Jaes    WMS-16096. Created                              */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal04]
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
            @cBUSR3 = ISNULL( BUSR3, ''),
            @cStyle = Style, 
            @cSize = Size,   
            @fSTDGrossWGT = STDGrossWGT, 
            @fSTDNetWGT = STDNetWGT
         FROM SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
            AND SKU = @cSKU
         
         -- SKU not yet catch weight 
         IF ( @fSTDGrossWGT = 0 OR @fSTDNetWGT = 0)   -- SKU not yet catch weight
         BEGIN
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_898UCCExtVal04 -- For rollback or commit only our own transaction
               
            -- Mark entire group catch weight
            INSERT INTO rdt.rdtCarterCubicGroupLog (CartonGroup, BUSR3, Style, Size) 
            VALUES (@cCartonGroup, @cBUSR3, @cStyle, @cSize)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 162401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
               GOTO RollBackTran
            END
            
            -- Mark as cubed
            UPDATE SKU SET
               IOFlag = '1'
            WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 162402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
               GOTO RollBackTran
            END
      
            -- Prompt for cubic scan
            SET @nErrNo = 162403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CubicScan
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            SET @nErrNo = 0
               
            COMMIT TRAN rdt_898UCCExtVal04
         END
      END
   END
   
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_898UCCExtVal04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO