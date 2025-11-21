SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_SerialCapture_ConfirmTask                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Process to insert ReceiptDetail                             */
/*                                                                      */
/* Called from: rdtfnc_SerialCapture_Receiving                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2011-03-30 1.0  ChewKP   Created                                     */
/* 2011-07-26 1.1  Audrey   SOS#221999 - fixed length from 10 to 20     */
/*                                                             (ang01)  */
/************************************************************************/
CREATE PROC [RDT].[rdt_SerialCapture_ConfirmTask] (
     @nMobile INT
    ,@cLangCode         NVARCHAR(3)
    ,@cStorerKey        NVARCHAR(15)
    ,@cUserName         NVARCHAR(15)
    ,@cFacility         NVARCHAR(5)
    ,@cReceiptKey       NVARCHAR(10)
    ,@cSerialNo         NVARCHAR(30)
    ,@cLOC              NVARCHAR(10)
    ,@cReceiptMethod    NVARCHAR(10)
    ,@cExternPOKey      NVARCHAR(20)
    ,@nErrNo            INT OUTPUT
    ,@cErrMsg           NVARCHAR(20) OUTPUT -- screen limitation, 20 char max


 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
           ,@n_err                 INT
           ,@c_errmsg              NVARCHAR(250)
           ,@nTranCount            INT



    DECLARE @cLottable01          NVARCHAR(18)
            ,@cLottable02         NVARCHAR(18)
            ,@cLottable03         NVARCHAR(18)
            ,@dLottable04         DateTime
            ,@cUserDefine01       NVARCHAR(30)
            ,@cUserDefine02       NVARCHAR(30)
            ,@cUserDefine03       NVARCHAR(30)
            ,@nSeqNo              INT
            ,@cSKU                NVARCHAR(20)
            ,@cNewReceiptLineNumber NVARCHAR(5)
            ,@cPackkey            NVARCHAR(10)
            ,@nCaseCnt            INT
            ,@cPackUOM            NVARCHAR(10)
            ,@cBatchNo            NVARCHAR(30)
            ,@cExternReceiptKey   NVARCHAR(20) --ang01
            ,@cBarCode            NVARCHAR(30)

    SET @nTranCount = @@TRANCOUNT



    BEGIN TRAN
    SAVE TRAN SerialCapture_ConfirmTask



--
--    SET @cExecStatements = N'DECLARE C_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR ' +
--                            ' SELECT PC.SeqNo, PC.SKU, PC.PackKey, Pack.CaseCnt ' +
--                            ' FROM dbo.PackConfig PC WITH (NOLOCK) ' +
--                            ' INNER JOIN Pack Pack WITH (NOLOCK) ON Pack.Packkey = PC.Packkey  ' +
--                            ' WHERE PC.Storerkey = @cStorerkey ' +
--                            ' AND UOM4BarCode = @cSerialNo '
--
--    SET @cExecArguments = N'@cStorerkey   NVARCHAR(15), ' +
--                           '@cSerialNo    NVARCHAR(30)  '
--
--    EXEC sp_executesql @cExecStatements, @cExecArguments, @cStorerkey, @cSerialNo
    SET @cLottable01 = ''
    SET @cLottable02 = ''
    SET @cLottable03 = ''
    SET @dLottable04 = NULL

    SET @cUserDefine01 = ''
    SET @cUserDefine02 = ''
    SET @cUserDefine03 = ''

    SET @cExternReceiptKey = ''


    SELECT @cExternReceiptKey = ExternReceiptKey FROM dbo.Receipt WITH (NOLOCK)
    WHERE Receiptkey = @cReceiptKey
    AND Storerkey = @cStorerkey



    IF @cReceiptMethod = 'UOM4'
    BEGIN
       SET @cUserDefine01 = ''
       SET @cUserDefine02 = @cSerialNo
       SET @cUserDefine03 = ''

       DECLARE C_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT PC.SKU, PC.PackKey, Pack.CaseCnt, Pack.PackUOM1, PC.BatchNo, PC.UOM1BarCode
       FROM dbo.PackConfig PC WITH (NOLOCK)
       INNER JOIN Pack Pack WITH (NOLOCK) ON Pack.Packkey = PC.Packkey
       WHERE PC.Storerkey = @cStorerkey
       AND UOM4BarCode = @cSerialNo
       AND ExternPOKey = @cExternPOKey


    END

    IF @cReceiptMethod = 'UOM1'
    BEGIN
       SET @cUserDefine01 = @cSerialNo
       SET @cUserDefine02 = ''
       SET @cUserDefine03 = ''

       DECLARE C_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT PC.SKU, PC.PackKey, Pack.CaseCnt, Pack.PackUOM1, PC.BatchNo, @cSerialNo
       FROM dbo.PackConfig PC WITH (NOLOCK)
       INNER JOIN Pack Pack WITH (NOLOCK) ON Pack.Packkey = PC.Packkey
       WHERE PC.Storerkey = @cStorerkey
       AND UOM1BarCode = @cSerialNo
       AND ExternPOKey = @cExternPOKey
    END

    IF @cReceiptMethod = 'UOM3'
    BEGIN
       SET @cUserDefine01 = ''
       SET @cUserDefine02 = ''
       SET @cUserDefine03 = @cSerialNo

       DECLARE C_ReceiptDetail CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT PC.SKU, PC.PackKey, Pack.CaseCnt, Pack.PackUOM3, PC.BatchNo, ''
       FROM dbo.PackConfig PC WITH (NOLOCK)
       INNER JOIN Pack Pack WITH (NOLOCK) ON Pack.Packkey = PC.Packkey
       WHERE PC.Storerkey = @cStorerkey
       AND UOM3BarCode = @cSerialNo
       AND ExternPOKey = @cExternPOKey
    END


    --IF @cReceiptMethod = 'UOM1' OR   @cReceiptMethod = 'UOM4'
    BEGIN
       OPEN C_ReceiptDetail

       FETCH NEXT FROM C_ReceiptDetail INTO @cSKU, @cPackkey, @nCaseCnt, @cPackUOM, @cBatchNo, @cBarCode

       WHILE (@@FETCH_STATUS <> -1)

       BEGIN -- WHILE LOOP START




           IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                  WHERE Receiptkey = @cReceiptkey
                  AND UserDefine03= @cSerialNo
                  AND SKU = @cSKU )
           BEGIN

                   UPDATE dbo.ReceiptDetail
                          SET  QTYExpected = QTYExpected +  1
                              , BeforeReceivedQTY = BeforeReceivedQTY + 1
                   WHERE Receiptkey = @cReceiptKey
                   AND UserDefine03 = @cSerialNo
                   AND SKU          = @cSKU

                  IF @@Error <> 0
                  BEGIN
                     SET @nErrNo = 72942
         			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdRecDetFailed'
         			   GOTO RollBackTran
                  END


--                  UPDATE dbo.PackConfig
--                  SET Status = '5'
--                  WHERE SeqNo = @nSeqNo
--                  AND Storerkey = @cStorerkey
--                  AND ExternPOKey = @cExternPOKey
--
--                  IF @@Error <> 0
--                  BEGIN
--                     SET @nErrNo = 72944
--         			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackCfgFailed'
--         			   GOTO RollBackTran
--                  END

           END
           ELSE
           BEGIN


               SET @cNewReceiptLineNumber = ''
               SELECT @cNewReceiptLineNumber =
               RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.ReceiptDetail (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey

               -- Insert new ReceiptDetail line
               INSERT INTO dbo.ReceiptDetail
   (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, QTYExpected, BeforeReceivedQTY,
                  ToID, ToLOC, ExternReceiptKey,
                  Status, DateReceived, UOM, PackKey, EffectiveDate, FinalizeFlag, SplitPalletFlag,
                  Lottable01, Lottable02, Lottable03, Lottable04,
                  UserDefine01, UserDefine02, UserDefine03 ) -- (ChewKP01)
               VALUES ( @cReceiptKey, @cNewReceiptLineNumber, @cStorerkey, @cSKU, @nCaseCnt, @nCaseCnt,
                        '', @cLoc, @cExternReceiptKey,
                        '0', GETDATE(), @cPackUOM, @cPackKey, GETDATE(), 'N', 'N',
                        @cLottable01, @cBatchNo, @cLottable03, @dLottable04,
                        CASE WHEN ISNULL(@cBarCode, '') <> '' THEN @cBarCode
                        ELSE ''
                        END,
                        ISNULL(@cUserDefine02, ''), ISNULL(@cUserDefine03, '') )

               IF @@Error <> 0
               BEGIN
                     SET @nErrNo = 72941
         			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsRecDetFailed'
         			   GOTO RollBackTran
               END






           END

         FETCH NEXT FROM C_ReceiptDetail INTO @cSKU, @cPackkey, @nCaseCnt, @cPackUOM, @cBatchNo, @cBarCode

         -- Update PackConfig base of Serial No

               IF @cReceiptMethod = 'UOM4'
               BEGIN
                  UPDATE dbo.PackConfig
                  SET Status = '5'
                  WHERE Storerkey = @cStorerkey
                  AND UOM4BarCode = @cSerialNo
                  AND ExternPOKey = @cExternPOKey

               END
               ELSE IF @cReceiptMethod = 'UOM1'
               BEGIN
                  UPDATE dbo.PackConfig
                  SET Status = '5'
                  WHERE Storerkey = @cStorerkey
                  AND UOM1BarCode = @cSerialNo
                  AND ExternPOKey = @cExternPOKey
               END
               ELSE IF @cReceiptMethod = 'UOM3'
               BEGIN
                  UPDATE dbo.PackConfig
                  SET Status = '5'
                  WHERE Storerkey = @cStorerkey
                  AND UOM3BarCode = @cSerialNo
                  AND ExternPOKey = @cExternPOKey
               END

               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 72945
      			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackCfgFailed'
      			   GOTO RollBackTran
               END

       END

       CLOSE C_ReceiptDetail
       DEALLOCATE C_ReceiptDetail
    END


    GOTO Quit

    RollBackTran:
    ROLLBACK TRAN SerialCapture_ConfirmTask
    CLOSE C_ReceiptDetail
    DEALLOCATE C_ReceiptDetail

    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN SerialCapture_ConfirmTask
END



GO