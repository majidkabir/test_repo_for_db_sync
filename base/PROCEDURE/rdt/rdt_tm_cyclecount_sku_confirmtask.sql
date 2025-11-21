SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_CycleCount_SKU_ConfirmTask                   */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_TM_CycleCount_SKU                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 17-11-2011 1.0  ChewKP   Created                                     */
/* 05-06-2013 1.1  Goh      Bug Fix (GOH01)                             */
/*            From US Prod - count by loc update sku.lastcyclecount too */
/* 05-05-2016 1.2  James    SOS350672 - Cater update CCDetail with      */
/*                          piece scanning (james01)                    */
/* 14-06-2018 1.3  James    INC0245481 - Bug fix on piece scanning      */
/*                          offset logic (james02)                      */
/* 06-10-2017 1.3  JihHaur  IN00484539 CCDetail add additional line(JH01)*/
/* 25-09-2023 1.4  James    WMS-23249 Add config allow Lottable05       */
/*                          null value when adding new line (james03)   */
/* 2023-10-12 1.5  James    WMS-23113 Add Lottable06 ~ 15 (james04)     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_TM_CycleCount_SKU_ConfirmTask] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
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
    ,@cLottable06      NVARCHAR( 30)
    ,@cLottable07      NVARCHAR( 30)
    ,@cLottable08      NVARCHAR( 30)
    ,@cLottable09      NVARCHAR( 30)
    ,@cLottable10      NVARCHAR( 30)
    ,@cLottable11      NVARCHAR( 30)
    ,@cLottable12      NVARCHAR( 30)
    ,@dLottable13      DATETIME
    ,@dLottable14      DATETIME
    ,@dLottable15      DATETIME
    ,@cUCC             NVARCHAR( 20)
    ,@cTaskDetailKey   NVARCHAR( 10)
    ,@cPickMethod      NVARCHAR( 10)
    ,@cLangCode        NVARCHAR( 3)
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
         , @nCCQty                INT
         , @cCCDetailKEy          NVARCHAR(10)
         , @cCCSheetNo            NVARCHAR(10)
         , @cNewCCDetailKey       NVARCHAR(10)
         , @nCountedQty           INT
         , @nTotalQty             INT
         , @cCCGroupExLottable05  NVARCHAR(1)
         , @nTotalRecord          INT
         , @nCounter              INT
         , @cLot                  NVARCHAR(10)
         , @dNewLottable05        DATETIME
         , @cDefaultQty           NVARCHAR( 5)  -- (james01)
         , @nDefaultQty           INT           -- (james01)
         , @cDefaultNullLottable05  NVARCHAR( 1)
         , @cSerialNoCapture      NVARCHAR( 1)

   SET @cCCGroupExLottable05 = ''
   SET @cCCGroupExLottable05 = rdt.RDTGetConfig( @nFunc, 'CCGroupExLottable05', @cStorerkey)

   SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
   IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
      SET @nDefaultQty = CAST( @cDefaultQty AS INT)
   ELSE
      SET @nDefaultQty = 0

   SET @cDefaultNullLottable05 = rdt.RDTGetConfig( @nFunc, 'DefaultNullLottable05', @cStorerkey)
   
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)

   SET @nTotalRecord = 0
   SET @bDebug = 0
   SET @nCounter = 1
   SET @cLot = ''

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
   --INSERT INTO TRACEINFO(TraceName, TimeIn, Col1, Col2, Col3, Col4) VALUES ('1768S', GETDATE(), @cLottable01, @cLottable02, @cLottable03, @cLottable06)
   SET @nTranCount = @@TRANCOUNT

   IF @dLottable04 = 0     SET @dLottable04 = NULL
   IF @dLottable05 = 0     SET @dLottable05 = NULL

   -- Truncate the time portion
   IF @dLottable04 IS NOT NULL
      SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)
   IF @dLottable05 IS NOT NULL
      SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)

--GOH01 Start
--	 SET @dNewLottable05 = CAST( CONVERT(VARCHAR(10), GETDATE(), 120) AS DATETIME )
   SET @dNewLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120)
--GOH01 End

   IF @cDefaultNullLottable05 = '1'
      SET @dNewLottable05 = NULL
      
   BEGIN TRAN
   SAVE TRAN TM_CC_SKU_ConfirmTask

   IF @cCCGroupExLottable05 = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKey    = @cCCKey
                  AND StorerKey  = @cStorerKey
                  AND Loc        = @cLoc
                  AND ID         = @cID
                  AND SKU        = @cSKU
                  AND Lottable01 = @cLottable01
                  AND Lottable02 = @cLottable02
                  AND Lottable03 = @cLottable03
                  AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
                  AND CCSheetNo  = @cTaskDetailKey  )
      BEGIN
         SELECT @nTotalRecord = COUNT(1) FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey    = @cCCKey
         AND StorerKey  = @cStorerKey
         AND Loc        = @cLoc
         AND ID         = @cID
         AND SKU        = @cSKU
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         AND CCSheetNo  = @cTaskDetailKey

         DECLARE CursorConfirmCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CCDetailKEy, SystemQty, Qty, Lot
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey      = @cCCKey
         AND Status       <> '9'
         AND SKU          = @cSKU
         AND StorerKEy    = @cStorerKey
         AND Loc          = @cLoc
         AND ID           = @cID
         AND Lottable01   = @cLottable01
         AND Lottable02   = @cLottable02
         AND Lottable03   = @cLottable03
         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         AND CCSheetNo    = @cTaskDetailKey
         ORDER BY CCDetailKey
      END
      ELSE
      BEGIN
         -- Add New CCDetail
         GOTO STEP_ADD_CCDETAIL
      END
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKey    = @cCCKey
                  AND StorerKey  = @cStorerKey
                  AND Loc        = @cLoc
                  AND ID         = @cID
                  AND SKU        = @cSKU
                  AND Lottable01 = @cLottable01
                  AND Lottable02 = @cLottable02
                  AND Lottable03 = @cLottable03
                  --AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
                  --AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0)
                  AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)  --(JH01)
				      AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable05, 120), 120), 0) = IsNULL( @dLottable05, 0)  --(JH01)
                  AND CCSheetNo  = @cTaskDetailKey  )
      BEGIN
         SELECT @nTotalRecord = COUNT(1) FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey    = @cCCKey
         AND StorerKey  = @cStorerKey
         AND Loc        = @cLoc
         AND ID         = @cID
         AND SKU        = @cSKU
         AND Lottable01 = @cLottable01
         AND Lottable02 = @cLottable02
         AND Lottable03 = @cLottable03
         --AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         --AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0)
         AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)  --(JH01)
		   AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable05, 120), 120), 0) = IsNULL( @dLottable05, 0)  --(JH01)
         AND CCSheetNo  = @cTaskDetailKey

         DECLARE CursorConfirmCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CCDetailKEy, SystemQty, Qty, Lot
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey      = @cCCKey
         AND Status       <> '9'
         AND SKU          = @cSKU
         AND StorerKEy    = @cStorerKey
         AND Loc          = @cLoc
         AND ID           = @cID
         AND Lottable01   = @cLottable01
         AND Lottable02   = @cLottable02
         AND Lottable03   = @cLottable03
         --AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)
         --AND IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0)
         AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)  --(JH01)
		   AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable05, 120), 120), 0) = IsNULL( @dLottable05, 0)  --(JH01)
         AND CCSheetNo    = @cTaskDetailKey
         ORDER BY CCDetailKey
      END
      ELSE
      BEGIN
         -- Add New CCDetail
         GOTO STEP_ADD_CCDETAIL
      END
   END

   OPEN CursorConfirmCC
   FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKEy, @nSystemQty, @nCCQty, @cLot
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nQty = 0
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET
         Qty           = 0
         ,Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
         WHERE CCKey       = @cCCKey
         AND CCSheetNo     = @cTaskDetailKey
         AND CCDetailKey   = @cCCDetailKEy
         AND StorerKey     = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74905
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
            GOTO RollBackTran
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cLocation     = @cLoc,
            @cToLocation   = '',
            @cID           = @cID,
            @cToID         = '',
            @cSKU          = @cSKU,
            @nQTY          = @nQty,
            @cRefNo1       = @cCCKey,
            @cRefNo2       = @cTaskDetailKey,
            @cRefNo3       = '',
            @cRefNo4       = ''
      END
      ELSE
      IF @nSystemQty = ( @nCCQty + @nQty)
      BEGIN
        UPDATE dbo.CCDetail WITH (ROWLOCK) SET
            Qty           = SystemQty
           ,Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
        WHERE CCKey       = @cCCKey
        AND CCSheetNo     = @cTaskDetailKey
        AND CCDetailKey   = @cCCDetailKEy
        AND StorerKey     = @cStorerKey

        IF @@ERROR <> 0
        BEGIN
           SET @nErrNo = 74906
           SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
           GOTO RollBackTran
        END

        -- EventLog - QTY
        EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3', -- Picking
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cLocation     = @cLoc,
           @cToLocation   = '',
           @cID           = @cID,
           @cToID         = '',
           @cSKU          = @cSKU,
           @nQTY          = @nQty,
           @cRefNo1       = @cCCKey,
           @cRefNo2       = @cTaskDetailKey,
           @cRefNo3       = '',
           @cRefNo4       = ''

        SET @nQty = 0
      END
      ELSE IF @nSystemQty < ( @nCCQty + @nQty)
      BEGIN
         IF @nSystemQty = 0
         BEGIN
            -- (james01)
            UPDATE dbo.CCDetail WITH (ROWLOCK) SET
               Qty           = CASE WHEN @nDefaultQty > 0 THEN Qty + @nQty 
                                    WHEN @cSerialNoCapture IN ('1', '2') THEN Qty + @nQty
                               ELSE @nQty END
              ,Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
            WHERE CCKey       = @cCCKey
            AND CCSheetNo     = @cTaskDetailKey
            AND CCDetailKey   = @cCCDetailKEy
            AND StorerKey     = @cStorerKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74911
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
               GOTO RollBackTran
            END

            SET @nQty = 0
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cLocation     = @cLoc,
            @cToLocation   = '',
            @cID           = @cID,
            @cToID         = '',
            @cSKU          = @cSKU,
            @nQTY          = @nQty,
            @cRefNo1       = @cCCKey,
            @cRefNo2       = @cTaskDetailKey,
            @cRefNo3       = '',
            @cRefNo4       = ''

         --SET @nQty = 0
      END
      ELSE IF @nSystemQty > ( @nCCQty + @nQty)
      BEGIN
         -- (james01)
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET
            Qty           = CASE WHEN @nDefaultQty > 0 THEN Qty + @nQty 
                                 WHEN @cSerialNoCapture IN ('1', '2') THEN Qty + @nQty
                            ELSE @nQty END
           ,Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
         WHERE CCKey       = @cCCKey
         AND CCSheetNo     = @cTaskDetailKey
         AND CCDetailKey   = @cCCDetailKEy
         AND StorerKey     = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74908
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
            GOTO RollBackTran
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cLocation     = @cLoc,
            @cToLocation   = '',
            @cID           = @cID,
            @cToID         = '',
            @cSKU          = @cSKU,
            @nQTY          = @nQty,
            @cRefNo1       = @cCCKey,
            @cRefNo2       = @cTaskDetailKey,
            @cRefNo3       = '',
            @cRefNo4       = ''

         SET @nQty = 0
      END

      FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKEy, @nSystemQty, @nCCQty, @cLot
   END
   CLOSE CursorConfirmCC
   DEALLOCATE CursorConfirmCC

   STEP_ADD_CCDETAIL:
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
               cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
               SystemQty, RefNo, Status)
      VALUES ( @cCCKey, @cNewCCDetailKey, @cStorerKey, @cSKU, '', @cLoc, @cID, @nQty, @cTaskDetailKey, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dNewLottable05, 
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               0, '', '4' )

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74902
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
         GOTO RollBackTran
      END

      -- EventLog - QTY
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3', -- Picking
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerKey,
           @cLocation     = @cLoc,
           @cToLocation   = '',
           @cID           = @cID,
           @cToID         = '',
           @cSKU          = @cSKU,
           @nQTY          = @nQty,
           @cRefNo1       = @cCCKey,
           @cRefNo2       = @cTaskDetailKey,
           @cRefNo3       = '',
           @cRefNo4       = ''

      SET @nQty = 0
   END

   IF @cPickMethod = 'SKU'
   BEGIN
      UPDATE dbo.SKU WITH (ROWLOCK) SET
         LastCycleCount = GETDATE()
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74909
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdSKUFail'
         GOTO RollBackTran
      END
   END
   ELSE IF @cPickMethod = 'LOC'
   BEGIN
      UPDATE dbo.LOC WITH (ROWLOCK) SET
         LastCycleCount = GETDATE()
      WHERE Loc = @cLoc

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74910
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocFail'
         GOTO RollBackTran
      END

       -- count by loc update sku.lastcyclecount too (jamesxxx)
      UPDATE dbo.SKU WITH (ROWLOCK) SET
         LastCycleCount = GETDATE()
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74909
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdSKUFail'
         GOTO RollBackTran
      END
   END

   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN TM_CC_SKU_ConfirmTask
   CLOSE CursorConfirmCC
   DEALLOCATE CursorConfirmCC

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
      COMMIT TRAN TM_CC_SKU_ConfirmTask
END

GO