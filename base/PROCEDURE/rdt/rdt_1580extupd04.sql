SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd04                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Update ReceiptDetail.UserDefine01 as serial no                    */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 08-03-2018  1.0  ChewKP      WMS-4126 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtUpd04]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount INT
   DECLARE @cRD_LOC NVARCHAR( 10) 
   DECLARE @cRD_SKU NVARCHAR( 20)
   DECLARE @cReceiptLineNumber NVARCHAR(5)
          ,@cOrderKey          NVARCHAR(10) 
          ,@cLot               NVARCHAR(10) 
          ,@cOrderLineNumber   NVARCHAR(5) 
          ,@bSuccess           INT
          ,@cPickDetailKey     NVARCHAR(10) 
          ,@cNewPickDetailKey  NVARCHAR( 10)
          ,@cPackKey           NVARCHAR(10) 
          ,@cLoadKey           NVARCHAR(10) 
          ,@cConfirmReceiptKey NVARCHAR(10)
          ,@cExternReceiptKey  NVARCHAR(20)
   
   

   SET @nTranCount = @@TRANCOUNT

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1580ExtUpd04 -- For rollback or commit only our own transaction
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
        IF @nStep = 1 
        BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               SELECT @cLoadKey = UserDefine03 
               FROM dbo.Receipt WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND ReceiptKey = @cReceiptKey
               
               IF EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
               BEGIN
               
                  IF EXISTS ( SELECT 1
                              FROM dbo.Storer S WITH (NOLOCK) 
                              INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.ConsigneeKey = S.StorerKey 
                              --INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.StorerKey = O.StorerKey
                              WHERE O.StorerKey = @cStorerKey 
                              AND O.LoadKey = @cLoadKey
                              --AND OD.SKU = @cSKUCode
                              AND ISNULL(S.SUSR5, '' )  = '' 
                              )
                  BEGIN
                     SET @nErrNo = 120004
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SUSR5Blank
                     GOTO RollBackTran
                  END
               END
            END
        END
--      IF @nStep = 1 -- ASN, POS
--      BEGIN
--         DECLARE @cDocType    NVARCHAR( 1)
--         DECLARE @cReceiptUDF NVARCHAR( 40)
--         DECLARE @cReturnFrom NVARCHAR( 30)
--         SELECT 
--            @cDocType = DocType, 
--            @cReceiptUDF = ISNULL( UserDefine01, '') + ISNULL( UserDefine02, ''), 
--            @cReturnFrom = ISNULL( UserDefine03, '')
--         FROM Receipt WITH (NOLOCK) 
--         WHERE ReceiptKey = @cReceiptKey
--         
--         IF @cDocType = 'R' AND  -- Return
--            @cReturnFrom = ''    -- Return from DYSON or non DYSON order. Blank = not yet determine
--         BEGIN
--            -- Check serial no sent out by us or others
--            IF EXISTS( SELECT 1 
--               FROM SerialNo WITH (NOLOCK) 
--               WHERE StorerKey = @cStorerKey 
--                  AND ISNULL( UserDefine01, '') + ISNULL( UserDefine02, '') = @cReceiptUDF)
--
--               SET @cReturnFrom = @cStorerKey
--            ELSE
--               SET @cReturnFrom = 'NON ' + @cStorerKey
--               
--            -- Update return from 
--            UPDATE Receipt SET
--               UserDefine03 = @cReturnFrom, 
--               EditDate = GETDATE(), 
--               EditWho = SUSER_SNAME(), 
--               TrafficCop = NULL
--            WHERE ReceiptKey = @cReceiptKey
--            IF @@ERROR <> 0
--            BEGIN
--               SET @nErrNo = 109403
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD RCPT Fail
--               GOTO RollBackTran
--            END
--         END
--      END

      

      IF @nStep = 10 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
--            -- Get hold LOC
--            DECLARE @cHoldLOC NVARCHAR( 10)
--            SET @cHoldLOC = rdt.RDTGetConfig( @nFunc, 'HoldLOC', @cStorerKey)         
            
            SELECT @cLoadKey = UserDefine03
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ReceiptKey = @cReceiptKey 

            IF EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
            BEGIN
            

               -- Finalize pallet
               IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                          INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey 
                          WHERE  RD.ToID = @cToID 
                              AND RD.FinalizeFlag <> 'Y'
                              AND RD.QTYReceived <> BeforeReceivedQTY
                              AND R.StorerKey = @cStorerKey
                              AND R.UserDefine03 = @cLoadKey
                              AND RD.BeforeReceivedQty > 0 )
               BEGIN
                  
                  
                  -- Loop ReceiptDetail of pallet
                  DECLARE @curRD CURSOR
                  SET @curRD = CURSOR FOR 
   --                  SELECT ReceiptLineNumber, ToLOC, SKU
   --                  FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   --                  WHERE ReceiptKey = @cReceiptKey
   --                     AND ToID = @cToID
                     
                     SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.ToLOC, RD.SKU
                     FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                     INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey 
                     WHERE RD.ToID = @cToID 
                       AND RD.FinalizeFlag <> 'Y'
                       AND RD.BeforeReceivedQty > 0 
                       AND R.StorerKey = @cStorerKey
                       AND R.UserDefine03 = @cLoadKey
                     ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
                  OPEN @curRD
                  FETCH NEXT FROM @curRD INTO @cConfirmReceiptKey, @cReceiptLineNumber, @cRD_LOC, @cRD_SKU
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Finalize ReceiptDetail
                     UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                        --Lottable08 = CASE WHEN Lottable08 = 'EXCESS' THEN '' ELSE Lottable08 END,
                        --Lottable09 = CASE WHEN Lottable08 = 'EXCESS' THEN '' ELSE Lottable09 END,
                        FinalizeFlag = 'Y',
                        QTYReceived = BeforeReceivedQTY, 
                        EditDate = GETDATE(), 
                        EditWho = SUSER_SNAME() 
                     WHERE ReceiptKey = @cConfirmReceiptKey
                        AND ReceiptLineNumber = @cReceiptLineNumber
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0
                     BEGIN
                        -- SET @nErrNo = 109401
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FinalizeRDFail
                        GOTO RollBackTran
                     END
                     
                     --SELECT @cConfirmReceiptKey '@cConfirmReceiptKey' , @cReceiptLineNumber '@cReceiptLineNumber' 
                     --SELECT FinalizeFlag , * from receiptdetail (nolocK) where receiptkey = @cConfirmReceiptKey and ReceiptLineNumber = @cReceiptLineNumber
                     --SELECT * FROM LotxLocxID WITH (NOLOCK) WHERE StorerKey = 'REV' and loc = @cRD_LOC and sku = @cRD_SKU 

                     FETCH NEXT FROM @curRD INTO @cConfirmReceiptKey, @cReceiptLineNumber, @cRD_LOC, @cRD_SKU
                  END
               END
               ELSE 
               BEGIN
                  SET @nErrNo = 120001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No RD Finalize
                  GOTO RollBackTran
               END
               
               --select * from lotxlocxid (nolocK) where loc = 'REVOVER' and ID = 'GIT001'

               -- Allocate Orders by Insert Pickdetail Information
               SET @cRD_LOC = '' 
               SET @cRD_SKU = ''
               SET @cReceiptLineNumber = '' 
               

               DECLARE @curPD CURSOR
               SET @curPD = CURSOR FOR 
               SELECT RD.ToLOC, RD.SKU, RD.Lottable09, LA.Lot, SUM(QtyReceived), RD.ExternReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey 
               INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (
                                                                        LA.StorerKey = RD.StorerKey
                                                                   AND  LA.SKU       = RD.SKU
                                                                   AND  ISNULL(LA.Lottable01,'') = ISNULL(RD.Lottable01,'')  
                                                                   AND  ISNULL(LA.Lottable02,'') = ISNULL(RD.Lottable02,'')  
                                                                   AND  ISNULL(LA.Lottable03,'') = ISNULL(RD.Lottable03,'')  
                                                                   AND  ISNULL(LA.Lottable04,'') = ISNULL(RD.Lottable04,'')  
                                                                   AND  ISNULL(LA.Lottable05,'') = ISNULL(RD.Lottable05,'')  
                                                                   AND  ISNULL(LA.Lottable06,'') = ISNULL(RD.Lottable06,'')  
                                                                   AND  ISNULL(LA.Lottable07,'') = ISNULL(RD.Lottable07,'')  
                                                                   AND  ISNULL(LA.Lottable08,'') = ISNULL(RD.Lottable08,'')  
                                                                   AND  ISNULL(LA.Lottable09,'') = ISNULL(RD.Lottable09,'')  
                                                                   AND  ISNULL(LA.Lottable10,'') = ISNULL(RD.Lottable10,'')  
                                                                   AND  ISNULL(LA.Lottable11,'') = ISNULL(RD.Lottable11,'')  
                                                                   AND  ISNULL(LA.Lottable12,'') = ISNULL(RD.Lottable12,'')  
                                                                   AND  ISNULL(LA.Lottable13,'') = ISNULL(RD.Lottable13,'')  
                                                                   AND  ISNULL(LA.Lottable14,'') = ISNULL(RD.Lottable14,'')  
                                                                   AND  ISNULL(LA.Lottable15,'') = ISNULL(RD.Lottable15,'')  
                                                                  )
               WHERE R.UserDefine03 = @cLoadKey
                  AND RD.ToID = @cToID
                  AND RD.FinalizeFlag = 'Y'
                  AND RD.Lottable09 <> '' 
                  AND RD.Lottable08 <> 'STOCK'
               GROUP BY RD.ReceiptLineNumber, RD.ToLOC, RD.SKU, RD.Lottable09, LA.Lot, RD.ExternReceiptKey
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cRD_LOC, @cRD_SKU, @cOrderKey, @cLot, @nQty , @cExternReceiptKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                                   WHERE StorerKey = @cStorerKey
                                   AND OrderKey    = @cOrderKey
                                   AND SKU         = @cRD_SKU
                                   AND Lot         = @cLot
                                   AND Loc         = @cToLOC
                                   AND ID          = @cToID )
                   BEGIN
                        SELECT TOP 1 @cOrderLineNumber = OrderLineNumber
                        FROM dbo.OrderDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND OrderKey = @cOrderKey
                        AND SKU = @cRD_SKU 

                        SELECT @cPackKey = PackKey
                        FROM dbo.SKU WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND SKU = @cRD_SKU
                        
                        -- Get new PickDetailkey
                        
                        EXECUTE dbo.nspg_GetKey
                           'PICKDETAILKEY',
                           10 ,
                           @cNewPickDetailKey OUTPUT,
                           @bSuccess          OUTPUT,
                           @nErrNo            OUTPUT,
                           @cErrMsg           OUTPUT
                        IF @bSuccess <> 1
                        BEGIN
                           SET @nErrNo = 120260
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                           GOTO RollBackTran
                        END

                        --SELECT @nQty '@nQty' , @cOrderKey '@cOrderKey' , @cLot '@cLot' , @cRD_LOC '@cRD_LOC' , @cToID '@cToID'  , @cRD_SKU '@cRD_SKU' 

                        --SELECT * FROM LotxLocxID WITH (NOLOCK) WHERE StorerKey = 'REV' and Lot = '0011092653' and loc = 'REVOVER' and id = 'PO18030091_T4'  
                  
                        INSERT INTO dbo.PickDetail (
                           CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                           UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                           ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                           EffectiveDate, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                           PickDetailKey,
                           QTY)
                        VALUES (
                           @cExternReceiptKey, '', @cOrderKey, @cOrderLineNumber, @cLot, @cStorerKey, @cRD_SKU, '', '6',
                           @nQty, 0, '0', '', @cRD_LOC, @cToID, @cPackKey, '0', 'STD',
                           '', '', 'N', '', 'N', '3', '',
                           GetDate(), 0, '', '', '', '',
                           @cNewPickDetailKey,
                           @nQty
                           ) 
                           
                        IF @@ERROR <> 0 
                        BEGIN
                           SET @nErrNo = 120002
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsPickDetFail
                           GOTO RollBackTran
                        END
                           
                           
                   END
                   ELSE 
                   BEGIN
                     SELECT @cPickDetailKey = PickDetailKey
                     FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey    = @cOrderKey
                     AND SKU         = @cRD_SKU
                     AND Lot         = @cLot
                     AND Loc         = @cToLOC
                     AND ID          = @cToID 
                     
                     
                     UPDATE dbo.PickDetail WITH (ROWLOCK) 
                     SET Qty = Qty + @nQty
                     WHERE StorerKey = @cStorerkey
                     AND PickDetailKey = @cPickDetailKey 
                     
                     IF @@ERROR <> 0 
                        BEGIN
                           SET @nErrNo = 120003
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFail
                           GOTO RollBackTran
                        END
                     END
   --                
                   FETCH NEXT FROM @curPD INTO @cRD_LOC, @cRD_SKU, @cOrderKey, @cLot, @nQty  , @cExternReceiptKey
               END
               
            END
            --COMMIT TRAN rdt_1580ExtUpd04 -- Only commit change made here
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1580ExtUpd04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1580ExtUpd04

END

GO