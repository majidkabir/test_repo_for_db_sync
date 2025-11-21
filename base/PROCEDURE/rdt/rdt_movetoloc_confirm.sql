SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_MoveToLOC_Confirm                                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-01-03 1.0  Ung      WMS-18656 Created                                 */
/* 2022-03-24 1.1  Ung      WMS-19133 Change record by user instead of mobile */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_MoveToLOC_Confirm] (
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT, 
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cType      NVARCHAR( 10), --LOG/UPDATE/UNDO
   @cFromLOC   NVARCHAR( 10),
   @cFromID    NVARCHAR( 18),
   @cSKU       NVARCHAR( 20),
   @nQTY       INT,
   @cToID      NVARCHAR( 18),
   @cToLOC     NVARCHAR( 10),
   @nTotalSKU  INT           OUTPUT, 
   @nTotalQTY  INT           OUTPUT, 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom move
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, ' + 
            ' @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@cType           NVARCHAR( 10), ' +
            '@cFromLOC        NVARCHAR( 10), ' +
            '@cFromID         NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@cToID           NVARCHAR( 18), ' +
            '@cToLOC          NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, 
            @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
	DECLARE @nRowRef  INT = 0
   DECLARE @curLog   CURSOR

   -- Write to log table
   IF @cType = 'LOG' 
   BEGIN
      -- Find the line with same SKU
      SELECT @nRowRef = RowRef
      FROM rdt.rdtMoveToLOCLog WITH (NOLOCK)
      WHERE AddWho = SUSER_SNAME()
         AND SKU = @cSKU
      
      IF @nRowRef > 0
      BEGIN
         UPDATE rdt.rdtMoveToLOCLog SET
            QTY = QTY + @nQTY
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         INSERT INTO rdt.rdtMoveToLOCLog (Mobile, StorerKey, FromLOC, FromID, SKU, QTY, ToLOC, ToID)
         VALUES (@nMobile, @cStorerKey, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToLOC, @cToID)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            GOTO Quit
         END
      END
      
      -- Get statistics
      SELECT
         @nTotalSKU = COUNT( DISTINCT SKU), 
         @nTotalQTY = SUM( QTY)
      FROM rdt.rdtMoveToLOCLog WITH (NOLOCK)
      WHERE AddWho = SUSER_SNAME()
      
      GOTO Quit
   END

   -- Move
   ELSE IF @cType = 'UPDATE' 
   BEGIN
      BEGIN TRAN
      SAVE TRAN rdt_MoveToLOC_Confirm

      -- Loop rdtMoveToLOCLog
      SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, SKU, QTY
         FROM rdt.rdtMoveToLOCLog WITH (NOLOCK)
         WHERE AddWho = SUSER_SNAME()
         ORDER BY RowRef
      OPEN @curLog
      FETCH NEXT FROM @curLog INTO @nRowRef, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Move
         EXECUTE rdt.rdt_Move
            @nMobile     	= @nMobile,
            @cLangCode   	= @cLangCode,
            @nErrNo      	= @nErrNo  OUTPUT,
            @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
            @cSourceType 	= 'rdtfnc_MoveToLOC',
            @cStorerKey  	= @cStorerKey,
            @cFacility   	= @cFacility,
            @cFromLOC    	= @cFromLOC,
            @cToLOC      	= @cToLOC,
            @cFromID     	= @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID       	= @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        	= @cSKU,
            @nQTY        	= @nQTY,
			   @nFunc   		= @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
            
         -- Offset
         DELETE rdt.rdtMoveToLOCLog
         WHERE RowRef = @nRowRef

         -- Log
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '3',
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey,
            @cLocation   = @cFromLOC,
            @cID         = @cFromID,
            @cSKU        = @cSKU,
            @nQTY        = @nQTY,
            @cToID       = @cToID,
            @cToLocation = @cToLOC
         
         FETCH NEXT FROM @curLog INTO @nRowRef, @cSKU, @nQTY
      END
      
      COMMIT TRAN rdt_MoveToLOC_Confirm
      GOTO Quit
   END
   
   -- Delete log table
   ELSE IF @cType = 'UNDO' 
   BEGIN
      BEGIN TRAN
      SAVE TRAN rdt_MoveToLOC_Confirm
      
      -- Loop rdtMoveToLOCLog
      SET @curLog = CURSOR FOR
         SELECT Rowref
         FROM rdt.rdtMoveToLOCLog WITH (NOLOCK)
         WHERE AddWho = SUSER_SNAME()
      OPEN @curLog
      FETCH NEXT FROM @curLog INTO @nRowref
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtMoveToLOCLog WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 180403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curLog INTO @nRowref
      END
      
      COMMIT TRAN rdt_MoveToLOC_Confirm
      GOTO Quit
   END
   ELSE
      GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_MoveToLOC_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO