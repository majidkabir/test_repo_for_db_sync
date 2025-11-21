SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_638Finalize01                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-11-14 1.0  James   WMS-10952. Created                              */
/* 2019-12-10 1.1  Ung     WMS-10952 Fix Receipt.Status                    */
/* 2020-08-04 1.2  Ung     WMS-13962 Migrate old finalize logic to this SP */
/* 2021-04-14 1.3  James   WMS-16668 Add Refno param (james01)             */
/* 2022-09-23 1.4  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_638Finalize01](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_638Finalize01

   -- Auto finalize upon receive
   DECLARE @cFinalizeRD NVARCHAR(1)
   SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetail', @cStorerKey)
   IF @cFinalizeRD IN ('', '0')
      SET @cFinalizeRD = '1' -- Default = 1

   -- Finalize ASN by line if no more variance
   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT ReceiptLineNumber
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   BeforeReceivedQTY > 0
   AND   FinalizeFlag <> 'Y'
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cFinalizeRD = '1'
      BEGIN
         -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)
         UPDATE dbo.ReceiptDetail SET
            QTYReceived = RD.BeforeReceivedQTY,
            FinalizeFlag = 'Y',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         FROM dbo.ReceiptDetail RD
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      IF @cFinalizeRD = '2'
      BEGIN
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @bSuccess   OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cReceiptLineNumber
         IF @nErrNo <> 0 OR @bSuccess = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM CUR_UPD INTO @cReceiptLineNumber
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   IF rdt.RDTGetConfig( @nFunc, 'CloseASNUponFinalize', @cStorerKey) = '1'
      AND @cFinalizeRD > 0
      AND NOT EXISTS ( SELECT 1
                       FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                       WHERE ReceiptKey = @cReceiptKey
                       AND   FinalizeFlag = 'N'
                       AND   BeforeReceivedQty > 0)
   BEGIN
      -- Close Status and ASNStatus here. If turn on config at WMS side then all ASN will be affected,
      -- no matter doctype. This only need for ecom ASN only. So use rdt config to control
      UPDATE dbo.RECEIPT SET
         ASNStatus = '9',
         -- Status    = '9',  -- Should not overule Exceed trigger logic
         ReceiptDate = GETDATE(),
         FinalizeDate = GETDATE(),
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   GOTO QUIT

   RollBackTran:
      ROLLBACK TRAN rdt_638Finalize01 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_638Finalize01


END

GO