SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_Move_UCC_Confirm                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: standard and custom confirm SP                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-05-04 1.0  Ung      WMS-12637 Created                                 */
/* 2023-01-20 1.1  Ung      WMS-21577 Add unlimited UCC to move               */
/* 2023-06-01 1.2  Ung      WMS-22561 Add UCCWithMultiSKU                     */
/* 2023-11-28 1.3  Ung      WMS-24170 Standardize LocationType from SKUxLOC   */
/* 2024-08-05 1.4  Ung      WMS-25998 Add UCC.Status = 3                      */
/* 2024-09-03 1.5  Ung      WMS-26113 Add force use standard logic            */
/* 2024-11-07 1.6  PXL009   Merged 1.4,1.5 from v0 branch                     */
/******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_Move_UCC_Confirm] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @i              INT           OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @nUseStandard   INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cConfirmSP  NVARCHAR( 20)
   DECLARE @nTranCount  INT

   SET @nTranCount = @@TRANCOUNT

   -- Get storer config
   IF @nUseStandard = 0
   BEGIN
      SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
      IF @cConfirmSP = '0'
         SET @cConfirmSP = ''  
   END

   /***********************************************************************************************
                                             Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
            ' @cToID, @cToLoc, @cFromLoc, @cFromID, ' + 
            ' @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, ' + 
            ' @i OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile        INT, ' +
            '@nFunc          INT, ' +
            '@cLangCode      NVARCHAR( 3),  ' +
            '@nStep          INT, ' +
            '@nInputKey      INT, ' + 
            '@cStorerKey     NVARCHAR( 15), ' +
            '@cFacility      NVARCHAR( 5),  ' +
            '@cToID          NVARCHAR( 18), ' +
            '@cToLoc         NVARCHAR( 10), ' +
            '@cFromLoc       NVARCHAR( 10), ' +
            '@cFromID        NVARCHAR( 18), ' +
            '@cUCC1          NVARCHAR( 20), ' +
            '@cUCC2          NVARCHAR( 20), ' +
            '@cUCC3          NVARCHAR( 20), ' +
            '@cUCC4          NVARCHAR( 20), ' +
            '@cUCC5          NVARCHAR( 20), ' +
            '@cUCC6          NVARCHAR( 20), ' +
            '@cUCC7          NVARCHAR( 20), ' +
            '@cUCC8          NVARCHAR( 20), ' +
            '@cUCC9          NVARCHAR( 20), ' +
            '@i              INT           OUTPUT, ' + 
            '@nErrNo         INT           OUTPUT, ' + 
            '@cErrMsg        NVARCHAR( 20) OUTPUT'
        
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cToID, @cToLoc, @cFromLoc, @cFromID, 
            @cUCC1, @cUCC2, @cUCC3, @cUCC4, @cUCC5, @cUCC6, @cUCC7, @cUCC8, @cUCC9, 
            @i OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END
   
   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @nRowCount      INT
   DECLARE @cUCC           NVARCHAR( 20)
   DECLARE @cUCCLOC        NVARCHAR( 10)
   DECLARE @cUCCID         NVARCHAR( 18)
   DECLARE @cUCCStatus     NVARCHAR( 10)
   DECLARE @nUCCQTY        INT
   DECLARE @cToLocType     NVARCHAR( 10)
   DECLARE @cLoseID        NVARCHAR( 1) 
   DECLARE @cLoseUCC       NVARCHAR( 1)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @nQTY           INT
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @cUCCWithMultiSKU   NVARCHAR( 1)

   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

   -- UCC status allowed
	SET @cUCCStatus = '1' -- Received
	IF @cMoveQTYAlloc = '1'
      SET @cUCCStatus += '3' -- Alloc

   -- Get ToLOC info
   IF @cUCCWithMultiSKU = '1'
   BEGIN
      SELECT
         @cLoseID = LoseID,
         @cLoseUCC = LoseUCC
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      SET @cToLocType = '' -- Default as BULK (just in case SKUxLOC not yet setup) 
      SELECT TOP 1 
         @cToLocType = LocationType
      FROM dbo.SKUxLOC (NOLOCK)
      WHERE LOC = @cToLOC
   END

   BEGIN TRAN
   SAVE TRAN rdt_Move_UCC_Confirm

   -- Loop UCC
   DECLARE @curUCC CURSOR
   SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RecNo, UCCNo
      FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND AddWho = SUSER_SNAME()
   OPEN @curUCC 
   FETCH NEXT FROM @curUCC INTO @i, @cUCC
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get FromLOC, FromID
      SELECT 
         @cUCCLOC = LOC, 
         @cUCCID = ID,
         @nUCCQTY = ISNULL( SUM( Qty), 0)
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
         AND CHARINDEX( Status, @cUCCStatus) > 0
      GROUP BY LOC, ID, SKU

      SET @nRowCount = @@ROWCOUNT

      -- Multi SKU UCC
      IF @cUCCWithMultiSKU = '1' AND @nRowCount > 1
      BEGIN
         -- Loop SKU
         DECLARE @curSKU CURSOR
         SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SKU, QTY, LOT
            FROM dbo.UCC (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
               AND CHARINDEX( Status, @cUCCStatus) > 0
            ORDER BY SKU
         OPEN @curSKU
         FETCH NEXT FROM @curSKU INTO @cSKU, @nQTY, @cLOT
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Calc QTY to move
            IF @cMoveQTYAlloc = '1'
            BEGIN
               SET @nQTYAlloc = @nQTY
               SET @nQTYPick = 0
            END
            ELSE IF @cMoveQTYPick = '1'
            BEGIN
               SET @nQTYAlloc = 0
               SET @nQTYPick = @nQTY
            END
            ELSE
            BEGIN
               SET @nQTYAlloc = 0
               SET @nQTYPick = 0
            END
            
            -- Move by SKU
            EXEC RDT.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, 
               @cSourceType = 'rdt_Move_UCC_Confirm', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cUCCLOC, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cUCCID,
               @cToID       = @cToID,
               @cSKU        = @cSKU, 
               @nQTY        = @nQTY,
               @nFunc       = @nFunc, 
               @nQTYAlloc   = @nQTYAlloc,
               @nQTYPick    = @nQTYPick,
               @cDropID     = @cUCC, 
               @cFromLOT    = @cLOT 
            IF @nErrNo <> 0
               GOTO RollBackTran
         
            FETCH NEXT FROM @curSKU INTO @cSKU, @nQTY, @cLOT
         END
         
         -- UCC
         UPDATE dbo.UCC SET
            LOC = @cToLOC, 
            ID = CASE WHEN @cLoseID = '1' THEN '' ELSE @cToID END,  
            Status = CASE WHEN (@cToLocType = 'PICK' OR @cToLocType = 'CASE') THEN '5'    
                          WHEN @cLoseUCC = '1' THEN '6'  
                          ELSE Status    
                     END, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE(), 
            TrafficCop = NULL
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 202151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
            GOTO RollBackTran
         END
      END
      
      -- Single SKU UCC
      ELSE
      BEGIN
         -- Calc QTY to move
         IF @cMoveQTYAlloc = '1'
         BEGIN
            SET @nQTYAlloc = @nUCCQTY
            SET @nQTYPick = 0
         END
         ELSE IF @cMoveQTYPick = '1'
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = @nUCCQTY
         END
         ELSE
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = 0
         END

         EXEC RDT.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode, 
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, 
            @cSourceType = 'rdt_Move_UCC_Confirm', 
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility, 
            @cFromLOC    = @cUCCLOC, 
            @cToLOC      = @cToLOC, 
            @cFromID     = @cUCCID,
            @cToID       = @cToID,
            @cSKU        = NULL, 
            @cUCC        = @cUCC,
            @nFunc       = @nFunc, 
            @nQTYAlloc   = @nQTYAlloc,
            @nQTYPick    = @nQTYPick,
            @cDropID     = @cUCC
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      
      -- Log event
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cLocation     = @cUCCLOC,
         @cToLocation   = @cToLOC,
         @cID           = @cUCCID, 
         @cToID         = @cToID, 
         @cRefNo1       = @cUCC, 
         @cUCC          = @cUCC

      FETCH NEXT FROM @curUCC INTO @i, @cUCC
   END

   COMMIT TRAN rdt_Move_UCC_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move_UCC_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO