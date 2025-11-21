SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_SerialNo_Delete                       */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Delete serial no in SerialNo and MasterSeialNo table        */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 03-10-2017  1.0  Ung          WMS-2953 Created                       */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_SerialNo_Delete]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15),
   @cSerialNo   NVARCHAR( 30),
   @nMasterKey  BIGINT, 
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSerialNoKey INT
   
   -- Get SNO
   SELECT @nSerialNoKey = SerialNoKey FROM SerialNo WITH (NOLOCK) WHERE SerialNo = @cSerialNo AND StorerKey = @cStorerKey

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_VerifySKU_SerialNo_Delete -- For rollback or commit only our own transaction
      
   -- Delete SNO
   IF @nSerialNoKey > 0
   BEGIN
      -- Delete SNO
      DELETE SerialNo WHERE SerialNoKey = @nSerialNoKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 56601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL SNO Fail
         GOTO RollbackTran
      END
   END            

   -- Delete piece SNO
   IF @nMasterKey > 0
   BEGIN
      DELETE MasterSerialNo WHERE MasterSerialNoKey = @nMasterKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 56602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL SNO Fail
         GOTO RollbackTran
      END
   END

   COMMIT TRAN rdt_VerifySKU_SerialNo_Delete
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_VerifySKU_SerialNo_Delete -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO