SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_TM_CycleCount_UCC_ConfirmTask                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Comfirm UCC count                                           */
/*                                                                      */
/* Called from: rdtfnc_TM_CycleCount_UCC                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 17-11-2011 1.0  ChewKP   Created                                     */
/* 19-12-2012 1.1  James    SOS257258 - TM CC Enhancement (james01)     */
/* 09-04-2015 1.2  James    Update SKU.LastCycleCount for count by loc  */
/*                          (james02)                                   */
/* 09-02-2020 1.3  YeeKung  Fix dateformat (yeekung01)                  */
/* 04-08-2023 1.4  James    WMS-23177 Stamp EditWho & EditDate when     */
/*                          confirm ucc count (james03)                 */
/* 09-11-2023 1.5  James    WMS-23249 Add CCDetailto withdraw when ucc  */
/*                          found in another loc (jamess04)             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_TM_CycleCount_UCC_ConfirmTask] (
     @nMobile          INT
    ,@cCCKey           NVARCHAR(10)
    ,@cStorerKey       NVARCHAR( 15)
    ,@cSKU             NVARCHAR( 20)
    ,@cLOC             NVARCHAR( 10)
    ,@cID              NVARCHAR( 18)
    ,@nQty             INT
    ,@nPackValue       INT
    ,@cUserName        NVARCHAR( 18)
    ,@cLottable01      NVARCHAR( 18)
    ,@cLottable02      NVARCHAR( 18)
    ,@cLottable03      NVARCHAR( 18)
    ,@dLottable04      DATETIME
    ,@dLottable05      DATETIME
    ,@cUCC             NVARCHAR( 20)
    ,@cPickMethod      NVARCHAR( 10)
    ,@cTaskDetailKey   NVARCHAR( 10)
    ,@cLangCode        NVARCHAR(3)
    ,@nErrNo           INT         OUTPUT
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @n_err                 INT
          , @c_errmsg              NVARCHAR(250)
          , @nTranCount            INT
          , @bDebug                INT
          , @nSystemQty            INT
          , @cCCDetailKEy          NVARCHAR(10)
          , @cCCSheetNo            NVARCHAR(10)
          , @cNewCCDetailKey       NVARCHAR(10)
          , @cWdLottable01         NVARCHAR( 18)
          , @cWdLottable02         NVARCHAR( 18)
          , @cWdLottable03         NVARCHAR( 18)
          , @dWdLottable04         DATETIME
          , @dWdLottable05         DATETIME
          , @cWdLoc                NVARCHAR( 10)
          , @cWdId                 NVARCHAR( 18)
          , @cWdLot                NVARCHAR( 10)

    SET @bDebug = 0

    IF @bDebug = 1
    BEGIN
        SELECT @cCCKey '@cCCKey'
       ,@cStorerKey        '@cStorerKey'
       ,@cSKU              '@cSKU'
       ,@cLOC              '@cLOC'
       ,@cID               '@cID'
       ,@nQty              '@nQty'
       ,@nPackValue        '@nPackValue'
       ,@cUserName         '@cUserName'
       ,@cLottable01       '@cLottable01'
       ,@cLottable02       '@cLottable02'
       ,@cLottable03       '@cLottable03'
       ,@dLottable04       '@dLottable04'
       ,@dLottable05       '@dLottable05'
       ,@cUCC              '@cUCC'
    END

    SET @nTranCount = @@TRANCOUNT

    IF @dLottable04 = 0     SET @dLottable04 = NULL
    IF @dLottable05 = 0     SET @dLottable05 = NULL

    -- Truncate the time portion
    IF @dLottable04 IS NOT NULL
       SET @dLottable04 = rdt.rdtconverttodate(@dLottable04)--CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)  (yeekung01)
    IF @dLottable05 IS NOT NULL
       SET @dLottable05 = rdt.rdtconverttodate(@dLottable05)--CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)  (yeekung01)

    IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                WHERE CCKey      = @cCCKey
                AND Status       = '0'
                AND SKU          = @cSKU
                AND StorerKEy    = @cStorerKey
                AND Loc          = @cLoc
                AND ID           = @cID
                AND Lottable01   = @cLottable01
                AND Lottable02   = @cLottable02
                AND Lottable03   = @cLottable03
                AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
                --AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0)
                AND CCSheetNo = @cTaskDetailKey )
    BEGIN
       BEGIN TRAN
       SAVE TRAN TM_CC_UCC_ConfirmTask

       DECLARE CursorConfirmCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

       SELECT CCDetailKey, CCSheetNo, SystemQty
       FROM dbo.CCDetail WITH (NOLOCK)
       WHERE CCKey      = @cCCKey
       AND Status       = '0'
       AND SKU          = @cSKU
       AND StorerKEy    = @cStorerKey
       AND Loc          = @cLoc
       AND ID           = @cID
       AND Lottable01   = @cLottable01
       AND Lottable02   = @cLottable02
       AND Lottable03   = @cLottable03
       AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
       --AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0)
       AND CCSheetNo = @cTaskDetailKey

       OPEN CursorConfirmCC
       FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKey, @cCCSheetNo, @nSystemQty

       WHILE @@FETCH_STATUS <> -1
       BEGIN
         -- FOR UCC Split CCDetail When Receive Different UCC
         IF @nSystemQty = @nQty
         BEGIN
            UPDATE dbo.CCDetail
              SET RefNo = @cUCC
                  ,Qty  = @nQty
                  ,Status = '2'
                  ,EditWho = @cUserName
                  ,EditDate = GETDATE()
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCDetailKey  = @cCCDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74852
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdCCDetFail'
               GOTO RollBackTran
            END

            SET @nQty = 0

         END
         ELSE IF @nSystemQty > @nQty
         BEGIN
            EXECUTE nspg_getkey
          'CCDetailKey'
          , 10
          , @cNewCCDetailKey OUTPUT
          , @b_success OUTPUT
          , @nErrNo OUTPUT
          , @cErrMsg OUTPUT

            INSERT INTO dbo.CCDetail (
                     cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
                   Lottable02, Lottable03, Lottable04, Lottable05, SystemQty, RefNo, STATUS, AddWho, AddDate        )
            SELECT CCKey, @cNewCCDetailKey, @cStorerKey, @cSKU, Lot, @cLoc, @cID, 0, CCSheetNo, @cLottable01,
                   @cLottable02, @cLottable03, @dLottable04, @dLottable05, SystemQty - @nQty, '', '0', @cUserName, GETDATE()
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCDetailKey  = @cCCDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74851
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
               GOTO RollBackTran
            END

            UPDATE dbo.CCDetail
              SET RefNo = @cUCC
                  ,Qty  = @nQty
                  ,Status = '2'
                  ,SystemQty = @nQty
                  ,EditWho = @cUserName
                  ,EditDate = GETDATE()
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCDetailKey  = @cCCDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74853
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdCCDetFail'
               GOTO RollBackTran
            END

            SET @nQTy = 0

         END
         ELSE IF @nSystemQty  < @nQty
         BEGIN
            UPDATE dbo.CCDetail
              SET RefNo = @cUCC
                  ,Qty  = SystemQty
                  ,Status = '2'
                  ,EditWho = @cUserName
                  ,EditDate = GETDATE()
            FROM dbo.CCDetail WITH (NOLOCK)
            WHERE CCDetailKey  = @cCCDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74855
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdCCDetFail'
               GOTO RollBackTran
            END

            SET @nQTy = @nQty - @nSystemQty

         END

         IF @nQty = 0
            BREAK

         FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKey, @cCCSheetNo, @nSystemQty

       END
       CLOSE CursorConfirmCC
       DEALLOCATE CursorConfirmCC
    END

    --IF  There is still remaining of @nQty
    --Create New CCTask to Store this Qty
    IF @nQty > 0
    BEGIN
       EXECUTE nspg_getkey
       'CCDetailKey'
       , 10
       , @cNewCCDetailKey OUTPUT
       , @b_success OUTPUT
       , @nErrNo OUTPUT
       , @cErrMsg OUTPUT

       INSERT INTO dbo.CCDetail (
               cckey, ccdetailkey, ccsheetno, StorerKey, sku, lot, loc, id, SystemQty, qty, Status, RefNo,
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, AddWho, AddDate)
       VALUES (@cCCKey, @cNewCCDetailKey, @cTaskDetailKey, @cStorerKey, @cSKU, '', @cLoc, @cID, 0, @nQty , '4', @cUCC,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cUserName, GETDATE())

       IF @@ERROR <> 0
       BEGIN
         SET @nErrNo = 74854
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
         GOTO RollBackTran
       END
    END

    IF @cPickMethod = 'SKU'
    BEGIN

       UPDATE dbo.SKU
       SET LastCycleCount = GETDATE(),
           EditWho = @cUserName,
           EditDate = GETDATE()
       WHERE StorerKey = @cStorerKey
       AND SKU = @cSKU

       IF @@ERROR <> 0
       BEGIN
             SET @nErrNo = 74857
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdSKUFail'
             GOTO RollBackTran
       END
    END
    ELSE IF @cPickMethod = 'LOC'
    BEGIN
       UPDATE dbo.LOC
       SET LastCycleCount = GETDATE(),
           EditWho = @cUserName,
           EditDate = GETDATE()
       WHERE Loc = @cLoc

       IF @@ERROR <> 0
       BEGIN
             SET @nErrNo = 74858
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocFail'
             GOTO RollBackTran
       END

       -- count by loc update sku.lastcyclecount too (james02)
       UPDATE dbo.SKU
       SET LastCycleCount = GETDATE(),
           EditWho = @cUserName,
           EditDate = GETDATE()
       WHERE StorerKey = @cStorerKey
       AND SKU = @cSKU

       IF @@ERROR <> 0
       BEGIN
             SET @nErrNo = 74857
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdSKUFail'
             GOTO RollBackTran
       END
    END
    GOTO Quit

    -- (james04)
    -- If ucc exists in another loc then create a ccdetail with 0 qty
    -- to let system withdraw it from the that loc
    IF EXISTS ( SELECT 1
                FROM dbo.UCC WITH (NOLOCK)
                WHERE Storerkey = @cStorerKey
                AND   UCCNo = @cUCC
                AND   Loc <> @cLOC)
    BEGIN
       SELECT
         @cWdLot = Lot,
         @cWdLoc = Loc,
         @cWdId = Id
       FROM dbo.UCC WITH (NOLOCK)
       WHERE Storerkey = @cStorerKey
       AND   UCCNo = @cUCC

       SELECT
         @cWdLottable01 = Lottable01,
         @cWdLottable02 = Lottable02,
         @cWdLottable03 = Lottable03,
         @dWdLottable04 = Lottable04,
         @dWdLottable05 = Lottable05
       FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
       WHERE Lot = @cWdLot

       EXECUTE nspg_getkey
       'CCDetailKey'
       , 10
       , @cNewCCDetailKey OUTPUT
       , @b_success OUTPUT
       , @nErrNo OUTPUT
       , @cErrMsg OUTPUT

       INSERT INTO dbo.CCDetail (
               cckey, ccdetailkey, ccsheetno, StorerKey, sku, lot, loc, id, SystemQty, qty, Status, RefNo,
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, AddWho, AddDate)
       VALUES (@cCCKey, @cNewCCDetailKey, @cTaskDetailKey, @cStorerKey, @cSKU, @cWdLot, @cWdLoc, @cWdId, 0, 0 , '4', @cUCC,
               @cWdLottable01, @cWdLottable02, @cWdLottable03, @dWdLottable04, @dWdLottable05, @cUserName, GETDATE())

       IF @@ERROR <> 0
       BEGIN
         SET @nErrNo = 74859
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
         GOTO RollBackTran
       END
    END

    RollBackTran:
    ROLLBACK TRAN TM_CC_UCC_ConfirmTask
    CLOSE CursorConfirmCC
    DEALLOCATE CursorConfirmCC

    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN TM_CC_UCC_ConfirmTask
END

GO