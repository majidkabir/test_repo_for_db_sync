SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtUpd04                                          */
/* Purpose: Update rdtPreReceiveSort2Log Qty                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-Feb-26 1.0  James    WMS-8010 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtUpd04] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT,
   @tExtendedUpdate VariableTable ReadOnly
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @nTranCount     INT
   DECLARE @nQty           INT
   DECLARE @nRowref        INT

   -- Variable mapping
   SELECT @nQty = ISNULL( Value, '') FROM @tExtendedUpdate WHERE Variable = '@nQty'

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1829ExtUpd04

   SET @nErrNo = 0
   SET @cReceiptKey = @cParam1

   IF @nStep = 4 -- End pre sort
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   StorerKey = @cStorerKey
      AND   [Status] < '9'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowref
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
            [Status] = '9',
            EditDate = GETDATE(),
            EditWho = sUser_sName() + '*'
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 134901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rel Loc Fail

            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowref
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         UPDATE [RDT].[rdtPreReceiveSort2Log] WITH (ROWLOCK) SET 
            Qty = ISNULL( Qty, 0) + @nQty
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cParam1
         AND   SKU = @cUCCNo
         AND   [Status] = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 134902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PreRcv Err
            GOTO RollBackTran
         END
         --insert into TraceInfo (tracename, timein, col1, col2, col3, col4) values ('1829', getdate(), @nQty, @cStorerKey, @cParam1, @cUCCNo)
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1829ExtUpd04
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO