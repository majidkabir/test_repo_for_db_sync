SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_SortCartonToPallet_ClosePallet                     */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Save carton to pallet                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-07-18   1.0  Ung      WMS-22855 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_SortCartonToPallet_ClosePallet](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cUpdateTable  NVARCHAR( 20), -- DROPID/PALLET
   @cPalletID     NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @nTranCount  INT
	DECLARE @cStatus     NVARCHAR( 10)
	
	SET @nTranCount = @@TRANCOUNT
	BEGIN TRAN
	SAVE TRAN ClosePallet

   -- DropID table
   IF @cUpdateTable = 'DROPID'
   BEGIN
      -- Close pallet
      UPDATE dbo.DropID SET
         Status = '9', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE Dropid = @cPalletID
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 204151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DROPIDFail
         GOTO RollBackTran
      END
   END
   
   -- Pallet table
   IF @cUpdateTable = 'PALLET'
   BEGIN
      -- Close pallet
      UPDATE dbo.Pallet SET
         Status = '9', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE PalletKey = @cPalletID
         AND Status = '0'
      IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 204152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UPD PLT Fail
         GOTO RollBackTran
      END
   END
   
   COMMIT TRAN Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO