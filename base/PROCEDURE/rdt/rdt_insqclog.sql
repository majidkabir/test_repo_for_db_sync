SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_InsQCLog                                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert QC information into rdt.rdtQCLog                     */
/*                                                                      */
/* Called from: rdt Pallet QC                                           */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2012-06-26  1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_InsQCLog] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cID              NVARCHAR( 18), 
   @cCartonID        NVARCHAR( 20), 
   @cTranType        NVARCHAR( 10), 
   @cTriageFlag      NVARCHAR( 10), 
   @cStatus          NVARCHAR( 10), 
   @cMissingCtn      NVARCHAR( 10), 
   @cNotes           NVARCHAR(255),
   @cCompleted       NVARCHAR(  1),
   @cLangCode        NVARCHAR(  3), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT 

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success         INT,
           @n_err             INT, 
           @c_errmsg          NVARCHAR( 20)
           
   DECLARE @nScanNo           INT, 
           @nTranCount        INT 

   DECLARE @cLastCompleted    NVARCHAR( 10), 
           @nLastScanNo       INT 

   SET @nErrNo = 0
   SET @cErrMsg = ''

   IF @cTranType = 'P'
   BEGIN
      SELECT TOP 1 
         @cLastCompleted = Completed, 
         @nLastScanNo = ScanNo 
      FROM rdt.rdtQCLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND TranType = 'P'
      ORDER BY SeqNo DESC
      
      IF ISNULL(@cLastCompleted, '') = 'Y'
      BEGIN
         SET @nLastScanNo = @nLastScanNo + 1
      END
   END
   
   IF @cTranType = 'C'
   BEGIN
--      SELECT @nLastScanNo = ISNULL(MAX( ScanNo), 0) + 1
--      FROM rdt.rdtQCLog WITH (NOLOCK) 
--      WHERE StorerKey = @cStorerKey
--         AND PalletID = @cID
--         AND CartonID = @cCartonID
--         AND TranType = 'C'

      -- C level scan no always same as P level
      SELECT TOP 1 
         @nLastScanNo = ScanNo 
      FROM rdt.rdtQCLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND PalletID = @cID
         AND TranType = 'P'
         AND Completed <> 'Y'
      ORDER BY SeqNo DESC
   END
   
   SET @nScanNo = @nLastScanNo
   
   IF ISNULL(@nScanNo, 0) = 0 OR @nScanNo = ''
   BEGIN
      SET @nScanNo = 1
   END

   IF ISNUMERIC(SUBSTRING(@cNotes, 1, 5)) = 1
   BEGIN
      SET @cNotes = SUBSTRING(@cNotes, 7, LEN(RTRIM(@cNotes)) - 6)
   END

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_InsQCLog

   INSERT INTO rdt.rdtQCLog
   (StorerKey, PalletID, ScanNo, TranType, CartonID, TriageFlag, AddWho, AddDate, Status, MissingCtn, Notes, Completed)
   VALUES
   (@cStorerKey, @cID, @nScanNo, @cTranType, @cCartonID, @cTriageFlag, @cUserName, GETDATE(), @cStatus, @cMissingCtn, @cNotes, @cCompleted)
   
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS QCLog Fail'
      GOTO RollBackTran
   END
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_InsQCLog

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_InsQCLog
END

GO