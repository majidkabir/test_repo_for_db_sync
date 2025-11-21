SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_598ExtUpd04                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Finalize by id if change id or esc from this module               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-07-08  James     1.0   WMS-17264 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_598ExtUpd04] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
   DECLARE @nTranCount     INT
   DECLARE @nFinalize      INT = 0
   DECLARE @cCur_ID        NVARCHAR( 18) = ''
   DECLARE @curRD          CURSOR
   DECLARE @cTempReceiptKey   NVARCHAR(10)


   SELECT @cCur_ID = V_ID
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 4 -- Sku
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            IF EXISTS ( SELECT 1 
                        FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                        JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
                        WHERE CR.Mobile = @nMobile
                        AND   RD.ToId = @cCur_ID
                        AND   RD.BeforeReceivedQty > 0
                        AND   RD.FinalizeFlag <> 'Y') 
               SET @nFinalize = 1
            
            IF @nFinalize = 0
               GOTO Quit
         END

         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN    
         SAVE TRAN rdt_598ExtUpd04    

         IF @nFinalize = 1
         BEGIN
            SET @curRD = CURSOR FOR
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.ToId = @cCur_ID
            AND   RD.BeforeReceivedQty > 0
            AND   RD.FinalizeFlag <> 'Y'
            OPEN @curRD
            FETCH NEXT FROM @curRD INTO @cTempReceiptKey, @cReceiptLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               EXEC dbo.ispFinalizeReceipt
                   @c_ReceiptKey        = @cTempReceiptKey
                  ,@b_Success           = @b_Success  OUTPUT
                  ,@n_err               = @nErrNo     OUTPUT
                  ,@c_ErrMsg            = @cErrMsg    OUTPUT
                  ,@c_ReceiptLineNumber = @cReceiptLineNumber
               IF @nErrNo <> 0 OR @b_Success = 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curRD INTO @cTempReceiptKey, @cReceiptLineNumber
            END
         END
      END
   END

   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_598ExtUpd04    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_598ExtUpd04    

END

GO