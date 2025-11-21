SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_605DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode scanned pre-printed pallet id and receive whole asn        */
/*                                                                            */
/* Called from: rdtfnc_PalletReceive                                          */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-03-23  James     1.0   WMS-21934 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_605DecodeSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cBarcode     NVARCHAR( 60),
   @cReceiptKey  NVARCHAR( 10)  OUTPUT,
   @cRefNo       NVARCHAR( 20)  OUTPUT,
   @cID          NVARCHAR( 18)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @curUpdReceipt        CURSOR
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)
   
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_605DecodeSP01 -- For rollback or commit only our own transaction
   
   IF @cBarcode = ''
      GOTO RollBackTran

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @curUpdReceipt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber
         FROM rdt.rdtPalletReceiveLog PRL WITH (NOLOCK)
         JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON ( PRL.ReceiptKey = RD.ReceiptKey)
         WHERE PRL.Mobile = @nMobile
         ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
         OPEN @curUpdReceipt
         FETCH NEXT FROM @curUpdReceipt INTO @cReceiptKey, @cReceiptLineNumber
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	UPDATE dbo.RECEIPTDETAIL SET 
         	   ToId = @cBarcode,
         	   EditWho = SUSER_SNAME(),
         	   EditDate = GETDATE()
         	WHERE ReceiptKey = @cReceiptKey
         	AND   ReceiptLineNumber = @cReceiptLineNumber
         	
         	IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 198251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stamp PID Err
               GOTO RollBackTran
            END
         
         	FETCH NEXT FROM @curUpdReceipt INTO @cReceiptKey, @cReceiptLineNumber
         END
         
         SET @cID = @cBarcode
      END
   END
   
   
   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_605DecodeSP01 
   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END

GO