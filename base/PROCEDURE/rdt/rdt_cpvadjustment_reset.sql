SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CPVAdjustment_Reset                             */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 14-Sep-2018 1.0  Ung       WMS-6149 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CPVAdjustment_Reset] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cType         NVARCHAR( 10), -- PARENT/CHILD 
   @cADJKey       NVARCHAR( 10), 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE @nRowRef INT
   DECLARE @nTranCount INT
   
   SET @nTranCount = @@TRANCOUNT

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Reset -- For rollback or commit only our own transaction

   -- Loop log
   DECLARE @curLog CURSOR 
   IF @cType = 'PARENT'
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK)
         WHERE ADJKey = @cADJKey
            AND Mobile = @nMobile
            AND Type = 'PARENT'
         ORDER BY RowRef
   ELSE
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtCPVAdjustmentLog WITH (NOLOCK)
         WHERE ADJKey = @cADJKey
            AND Mobile = @nMobile
            AND Type = 'CHILD'
         ORDER BY RowRef

   OPEN @curLog 
   FETCH NEXT FROM @curLog INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE rdt.rdtCPVAdjustmentLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 129401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
         GOTO RollbackTran
      END
      FETCH NEXT FROM @curLog INTO @nRowRef
   END

   COMMIT TRAN rdt_Reset
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Reset -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO