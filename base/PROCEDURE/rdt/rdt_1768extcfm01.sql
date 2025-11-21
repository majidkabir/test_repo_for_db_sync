SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1768ExtCfm01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Comfirm CC Task                                             */
/*                                                                      */
/* Called from: rdtfnc_TM_CycleCount_SKU                                */
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2018-06-18  1.0  James    WMS-4614 Created                           */
/************************************************************************/    

CREATE PROC [RDT].[rdt_1768ExtCfm01] (    
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cTaskDetailKey  NVARCHAR( 10),
   @cCCKey          NVARCHAR( 10),
   @cCCDetailKey    NVARCHAR( 10),
   @cPickMethod     NVARCHAR( 10),
   @cLoc            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT, 
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR( 30),
   @cLottable07     NVARCHAR( 30),
   @cLottable08     NVARCHAR( 30),
   @cLottable09     NVARCHAR( 30),
   @cLottable10     NVARCHAR( 30),
   @cLottable11     NVARCHAR( 30),
   @cLottable12     NVARCHAR( 30),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,  
   @dLottable15     DATETIME,  
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT 
) AS    
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
         , @cCCSheetNo            NVARCHAR(10)
         , @cNewCCDetailKey       NVARCHAR(10)
         , @nCountedQty           INT
         , @nTotalQty             INT
         , @nTotalRecord          INT
         , @nCounter              INT
         , @cLot                  NVARCHAR(10)
         , @dNewLottable05        DATETIME
         , @cUserName            NVARCHAR( 5)  
         , @cFacility            NVARCHAR( 5)  

   SET @nTotalRecord = 0
   SET @bDebug = 0
   SET @nCounter = 1
   SET @cLot = ''

   SET @nTranCount = @@TRANCOUNT

   IF @dLottable04 = 0     SET @dLottable04 = NULL  
   IF @dLottable05 = 0     SET @dLottable05 = NULL  

   -- Truncate the time portion  
   IF @dLottable04 IS NOT NULL  
      SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)  
   IF @dLottable05 IS NOT NULL  
      SET @dLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable05, 120), 120)  

   SET @dNewLottable05 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), GETDATE(), 120), 120)    

   SELECT @cUserName = UserName, 
          @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   BEGIN TRAN
   SAVE TRAN rdt_1768ExtCfm01
    
   IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey    = @cCCKey
               AND StorerKey  = @cStorerKey
               AND Loc        = @cLoc
               AND ID         = @cID
               AND SKU        = @cSKU
               AND Lottable01 = @cLottable01
               AND Lottable02 = @cLottable02
               AND Lottable03 = @cLottable03
               AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)
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
      AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)
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
      AND IsNULL( CONVERT( DATETIME, CONVERT( NVARCHAR( 10), Lottable04, 120), 120), 0) = IsNULL( @dLottable04, 0)
      AND CCSheetNo    = @cTaskDetailKey
      ORDER BY CCDetailKey
   END
   ELSE
   BEGIN
      -- Add New CCDetail
      GOTO STEP_ADD_CCDETAIL
   END

   OPEN CursorConfirmCC            
   FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKEy, @nSystemQty, @nCCQty, @cLot
   WHILE @@FETCH_STATUS <> -1            
   BEGIN   
      IF @nQTY = 0 
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
         Qty           = 0,
         Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
         WHERE CCKey       = @cCCKey
         AND CCSheetNo     = @cTaskDetailKey
         AND CCDetailKey   = @cCCDetailKEy
         AND StorerKey     = @cStorerKey

         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 125301
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDetFail'
            GOTO RollBackTran
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '8', -- Cycle Count
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
            @nQTY          = @nQTY,
            @cRefNo1       = @cCCKey,  
            @cRefNo2       = @cTaskDetailKey,   
            @cRefNo3       = '',
            @cRefNo4       = ''
      END
      ELSE
      IF @nSystemQty = ( @nCCQty + @nQTY)
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
            Qty           = SystemQty,
            Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
         WHERE CCKey       = @cCCKey
         AND CCSheetNo     = @cTaskDetailKey
         AND CCDetailKey   = @cCCDetailKEy
         AND StorerKey     = @cStorerKey

        IF @@ERROR <> 0 
        BEGIN
           SET @nErrNo = 125302
           SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDetFail'
           GOTO RollBackTran
        END

        -- EventLog - QTY
        EXEC RDT.rdt_STD_EventLog
           @cActionType   = '8', -- Cycle Count
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
           @nQTY          = @nQTY,
           @cRefNo1       = @cCCKey,  
           @cRefNo2       = @cTaskDetailKey,   
           @cRefNo3       = '',
           @cRefNo4       = ''

        SET @nQTY = 0    
      END
      ELSE IF @nSystemQty < ( @nCCQty + @nQTY)
      BEGIN
         IF @nSystemQty = 0
         BEGIN 
            UPDATE dbo.CCDetail WITH (ROWLOCK) SET
               Qty           = Qty + @nQTY,
               Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
            WHERE CCKey       = @cCCKey
            AND CCSheetNo     = @cTaskDetailKey
            AND CCDetailKey   = @cCCDetailKEy
            AND StorerKey     = @cStorerKey

            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 125303
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDetFail'
               GOTO RollBackTran
            END       

            SET @nQTY = 0 
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '8', -- Cycle Count
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
            @nQTY          = @nQTY,
            @cRefNo1       = @cCCKey,  
            @cRefNo2       = @cTaskDetailKey,   
            @cRefNo3       = '',
            @cRefNo4       = ''

         --SET @nQty = 0   
      END
      ELSE IF @nSystemQty > ( @nCCQty + @nQTY)
      BEGIN
         UPDATE dbo.CCDetail WITH (ROWLOCK) SET
            Qty           = Qty + @nQTY,
            Status        = CASE WHEN Status = '4' THEN Status ELSE '2' END
         WHERE CCKey       = @cCCKey
         AND CCSheetNo     = @cTaskDetailKey
         AND CCDetailKey   = @cCCDetailKEy
         AND StorerKey     = @cStorerKey

         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 125304
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDetFail'
            GOTO RollBackTran
         END

         -- EventLog - QTY
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '8', -- Cycle Count
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
            @nQTY          = @nQTY,
            @cRefNo1       = @cCCKey,  
            @cRefNo2       = @cTaskDetailKey,   
            @cRefNo3       = '',
            @cRefNo4       = ''

         SET @nQTY = 0
      END

      FETCH NEXT FROM CursorConfirmCC INTO @cCCDetailKEy, @nSystemQty, @nCCQty, @cLot
   END
   CLOSE CursorConfirmCC            
   DEALLOCATE CursorConfirmCC  

   STEP_ADD_CCDETAIL:
   IF @nQTY > 0 
   BEGIN
      SET @nErrNo = 0
      EXECUTE nspg_getkey
   	      'CCDetailKey'
   	      , 10
   	      , @cNewCCDetailKey OUTPUT
   	      , @b_success OUTPUT
   	      , @nErrNo OUTPUT
   	      , @cErrMsg OUTPUT

      IF @nErrNo <> 0 
      BEGIN
         SET @nErrNo = 125305
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GetKey Fail'
         GOTO RollBackTran
      END

      INSERT INTO dbo.CCDetail (
               cckey, ccdetailkey, StorerKey, sku, lot, loc, id, qty, ccsheetno, Lottable01,
               Lottable02, Lottable03, Lottable04, Lottable05, SystemQty, RefNo, Status        )
      VALUES ( @cCCKey, @cNewCCDetailKey, @cStorerKey, @cSKU, '', @cLoc, @cID, @nQTY, @cTaskDetailKey, @cLottable01,
             @cLottable02, @cLottable03, @dLottable04, @dNewLottable05, 0, '', '4' )

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 125306
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCDetFail'
         GOTO RollBackTran
      END

      -- EventLog - QTY
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '8', -- Cycle Count
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
           @nQTY          = @nQTY,
           @cRefNo1       = @cCCKey,  
           @cRefNo2       = @cTaskDetailKey,   
           @cRefNo3       = '',
           @cRefNo4       = ''

      SET @nQTY = 0
   END

   IF @cPickMethod = 'SKU'
   BEGIN
      UPDATE dbo.SKU WITH (ROWLOCK) SET
         LastCycleCount = GETDATE()
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 125307
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDateFail'
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
         SET @nErrNo = 125308
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDateFail'
         GOTO RollBackTran
      END

       -- count by loc update sku.lastcyclecount too 
      UPDATE dbo.SKU WITH (ROWLOCK) SET 
         LastCycleCount = GETDATE()
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 125309
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Upd CCDateFail'
         GOTO RollBackTran
      END      
   END

   GOTO QUIT

   RollBackTran:
      ROLLBACK TRAN rdt_1768ExtCfm01

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1768ExtCfm01
END

GO