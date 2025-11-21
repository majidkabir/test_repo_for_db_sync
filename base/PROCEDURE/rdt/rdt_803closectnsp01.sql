SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store procedure: rdt_803CloseCtnSP01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close station                                               */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 01-03-2021 1.0  YeeKung    WMS-16066 Created                         */
/* 02-12-2022 1.1  Ung        WMS-21112 Add NewCartonID param           */
/* 30-11-2022 1.2  Ung        WMS-21170 Add light param                 */
/************************************************************************/

CREATE   PROC [RDT].[rdt_803CloseCtnSP01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cPosition    NVARCHAR( 20)
   ,@cLOC         NVARCHAR( 20)
   ,@cCartonID    NVARCHAR( 20)
   ,@cNewCartonID NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_803CloseCtnSP01 -- For rollback or commit only our own transaction

   UPDATE rdt.rdtPTLPieceLog SET
      CartonID = @cNewCartonID,
      SKU = '', 
      EditDate = GETDATE(),
      EditWho = SUSER_SNAME()
   WHERE LOC = @cLOC

   IF @@ERROR<>0
   BEGIN
      SET @nErrNo = 165051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPTLPieceFail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_803CloseCtnSP01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_803CloseCtnSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO