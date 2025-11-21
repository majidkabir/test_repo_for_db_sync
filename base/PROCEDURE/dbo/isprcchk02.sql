SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispRCCHK02                                          */
/* Copyright: IDS                                                       */
/* Purpose: CN VF project                                               */
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-03-14   Ung       1.0   SOS255639 Check ReceiptDetail vs UCC    */
/*                              SOS288143 Return                        */
/* 2014-01-20   YTWan     1.1   SOS#298639 - Washington - Finalize by   */
/*                              Receipt Line. Add Default parameters    */
/*                              @c_ReceiptLineNumber.(Wan01)            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRCCHK02]
   @cReceiptKey NVARCHAR(10),
   @bSuccess    INT = 1  OUTPUT,
   @nErrNo      INT = 0  OUTPUT,
   @cErrMsg     NVARCHAR(250) = '' OUTPUT
,  @c_ReceiptLineNumber  NVARCHAR(5) = ''       --(Wan01)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cRecType    NVARCHAR( 10)
   DECLARE @cDocType    NVARCHAR( 1)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nRDQTY      INT
   DECLARE @nUCCQTY     INT
   DECLARE @cUDF01      NVARCHAR( 30)
   DECLARE @cUDF02      NVARCHAR( 30)
   DECLARE @cUDF03      NVARCHAR( 30)
   DECLARE @cReturnType NVARCHAR( 10)
   DECLARE @cToLocType  NVARCHAR( 10)
   DECLARE @cProcessType NVARCHAR( 1)
   DECLARE @cReceiptLineNumber NVARCHAR( 5)

   SET @bSuccess = 1
   SET @nTranCount = @@TRANCOUNT

   -- Get Receipt info
   SELECT
      @cDocType = DocType,
      @cRecType = RecType, 
      @cStorerKey = StorerKey, 
      @cUDF01 = UserDefine01, 
      @cUDF02 = UserDefine02, 
      @cUDF03 = UserDefine03, 
      @cProcessType = ProcessType
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   -- Return 
   IF @cDocType = 'R'
   BEGIN
      -- Get return type
      SELECT @cReturnType = Short
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RECTYPE'
         AND Code = @cRecType
         AND StorerKey = @cStorerKey
   
      BEGIN TRAN
      SAVE TRAN ispRCCHK02

      -- Loop ReceiptDetail
      DECLARE @curRD CURSOR
      SET @curRD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ReceiptLineNumber, ToLOC, ToID
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      OPEN @curRD
      FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cToLOC, @cToID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get ToLOC type
         SET @cToLocType = ''
         SELECT @cToLocType = Short
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'TOLOC'
            AND Code = @cToLOC
            AND StorerKey = @cStorerKey
         
         -- Wholesale return
         IF @cReturnType = 'W'
         BEGIN
            -- Good stock
            IF @cToLocType = 'GD'
            BEGIN
               UPDATE ReceiptDetail SET
                  UserDefine01 = @cToID
               WHERE ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cReceiptLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @cErrMsg = 'Error update LineNo=' + @cReceiptLineNumber + 
                     '. ReturnType=' + RTRIM( @cReturnType) + 
                     '. ToLocType=' + RTRIM( @cToLocType) + 
                     ' (ispRCCHK02)'
                  GOTO RollbackTran
               END
            END
         END

         -- Transfer from 3rd party logistic (move warehouse)
         IF @cReturnType = 'TRF'
         BEGIN
            -- Good stock
            IF @cToLocType = 'GD'
            BEGIN
               UPDATE ReceiptDetail SET
                  UserDefine01 = @cToID, 
                  Lottable01 = LEFT( @cUDF01, 18), 
                  Lottable02 = LEFT( @cUDF02, 18), 
                  Lottable03 = LEFT( @cUDF03, 18) 
               WHERE ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cReceiptLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @cErrMsg = 'Error update LineNo=' + @cReceiptLineNumber + 
                     '. ReturnType=' + RTRIM( @cReturnType) + 
                     '. ToLocType=' + RTRIM( @cToLocType) + 
                     ' (ispRCCHK02)'
                  GOTO RollbackTran
               END
            END

            -- Damage stock
            IF @cToLocType = 'DMG'
            BEGIN
               UPDATE ReceiptDetail SET
                  Lottable01 = LEFT( @cUDF01, 18), 
                  Lottable02 = LEFT( @cUDF02, 18), 
                  Lottable03 = LEFT( @cUDF03, 18) 
               WHERE ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cReceiptLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @cErrMsg = 'Error update LineNo=' + @cReceiptLineNumber + 
                     '. ReturnType=' + RTRIM( @cReturnType) + 
                     '. ToLocType=' + RTRIM( @cToLocType) + 
                     ' (ispRCCHK02)'
                  GOTO RollbackTran
               END
            END
         END

         FETCH NEXT FROM @curRD INTO @cReceiptLineNumber, @cToLOC, @cToID
      END
      
      COMMIT TRAN ispRCCHK02
   END

   -- Normal receipt
   IF @cDocType <> 'R'
   BEGIN
      -- Receipt without UCC
      IF @cProcessType = 'B'
      BEGIN
         UPDATE ReceiptDetail SET
            UserDefine01 = ToID
         WHERE ReceiptKey = @cReceiptKey
         IF @@ERROR <> 0
         BEGIN
            SET @cErrMsg = 'Error update ReceiptDetail' + 
               '. DocType=' + RTRIM( @cDocType) + 
               '. ProcessType=' + RTRIM( @cProcessType) + 
               ' (ispRCCHK02)'
            GOTO RollbackTran
         END
      END  
      
      -- Receipt with UCC
      IF @cProcessType <> 'B'
      BEGIN
         SET @cSKU = ''
         SELECT TOP 1 
            @cToLOC = RD.ToLOC, 
            @cToID = RD.ToID, 
            @cSKU = RD.SKU, 
            @nRDQTY = SUM( BeforeReceivedQTY), 
            @nUCCQTY = 
               (SELECT SUM( UCC.QTY) 
               FROM UCC WITH (NOLOCK)
               WHERE RD.ReceiptKey = UCC.ReceiptKey 
                  AND RD.ToLOC = UCC.LOC 
                  AND RD.ToID = UCC.ID 
                  AND RD.SKU = UCC.SKU 
                  AND UCC.Status = '1')
         FROM ReceiptDetail RD
         WHERE RD.ReceiptKey = @cReceiptKey
         GROUP BY RD.ReceiptKey, RD.ToLOC, RD.ToID, RD.SKU
         HAVING SUM( BeforeReceivedQTY) <> 
            (SELECT SUM( UCC.QTY) 
            FROM UCC WITH (NOLOCK)
            WHERE RD.ReceiptKey = UCC.ReceiptKey 
               AND RD.ToLOC = UCC.LOC 
               AND RD.ToID = UCC.ID 
               AND RD.SKU = UCC.SKU 
               AND UCC.Status = '1')
      
         IF @cSKU <> ''
         BEGIN
            SET @bSuccess = 0
            SET @cErrMsg = 'ReceiveDetail.QTY <> UCC.QTY. ' + 
               ' SKU=' + RTRIM( @cSKU) + 
               ' LOC=' + RTRIM( @cToLOC) + 
               ' ID=' + RTRIM( @cToID) + 
               ' RDQTY=' + CAST( @nRDQTY AS NVARCHAR( 10)) + 
               ' UCCQTY=' + CAST( @nUCCQTY AS NVARCHAR( 10)) + 
               ' (ispRCCHK02)'
         END
      END
   END
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN ispRCCHK02
      SET @bSuccess = 0
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO