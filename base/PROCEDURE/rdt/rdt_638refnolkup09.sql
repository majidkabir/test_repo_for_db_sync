SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP09                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 26-10-2022   Ung       1.0   WMS-21002 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RefNoLKUP09]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 20)  OUTPUT
   ,@cReceiptKey  NVARCHAR( 10)  OUTPUT
   ,@nBalQTY      INT            OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @cNewReceiptKey NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT

   -- Receipt not found
   IF @cReceiptKey = ''
   BEGIN
      -- Get ASN info
      SELECT @cReceiptKey = ReceiptKey
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ExternReceiptKey = @cRefNo
         AND StorerKey = @cStorerKey
         AND Status = '0'
      
      -- Create new ASN
      IF @cReceiptKey = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'RECEIPT',
            10 ,
            @cNewReceiptKey OUTPUT,
            @bSuccess       OUTPUT,
            @nErrNo         OUTPUT,
            @cErrMsg        OUTPUT
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 193351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO Quit
         END

         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_638RefNoLKUP09 -- For rollback or commit only our own transaction

         -- Copy Orders to Receipt
         INSERT INTO dbo.Receipt
            (ReceiptKey, Facility, StorerKey, ExternReceiptKey, UserDefine01, RecType, ReceiptGroup, DocType, ASNReason, Appointment_no)
         VALUES
            (@cNewReceiptKey, @cFacility, @cStorerKey, @cRefNo, @cRefNo, 'GRN', 'DEVW', 'R', '12', 'R51')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 193352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS ASN fail
            GOTO RollBackTran
         END

         SET @cReceiptKey = @cNewReceiptKey
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_638RefNoLKUP09
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO