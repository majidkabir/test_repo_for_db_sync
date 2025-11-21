SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1650ExtUpd04                                    */
/* Purpose: Handle pallet with CBOM key or MBOL key                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-12-16 1.0  CYU027     FCR-1606 Create                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1650ExtUpd04] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cPalletID        NVARCHAR( 20), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1),  
   @nAfterStep       INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount             INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN rdt_1650ExtUpd04
   SAVE TRAN rdt_1650ExtUpd04

   --Call 1650ExtUpd01
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = object_id(N'rdt.rdt_1650ExtUpd01') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
   BEGIN
      SET @nErrNo = 231051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --1650ExtUpd01 is Missing
      GOTO Quit
   END

   EXEC [RDT].[rdt_1650ExtUpd01]
        @nMobile          = @nMobile,
        @nFunc            = @nFunc,
        @nStep            = @nStep,
        @cLangCode        = @cLangCode,
        @nInputKey        = @nInputKey,
        @cStorerKey       = @cStorerKey,
        @cPalletID        = @cPalletID,
        @cMbolKey         = @cMbolKey,
        @cDoor            = @cDoor,
        @cOption          = @cOption,
        @nAfterStep       = @nAfterStep,
        @nErrNo           = @nErrNo OUTPUT,
        @cErrMsg          = @cErrMsg OUTPUT

   IF @nErrNo <> 0
   BEGIN
      SET @nErrNo = 231052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --loseTruckFail
      GOTO ROLLBACKTran
   END

   --UPDATE PalletDetail
   UPDATE dbo.PALLET WITH (ROWLOCK) SET
      [Status] = 9
   WHERE PalletKey = @cPalletID

   IF @nErrNo <> 0
   BEGIN
      SET @nErrNo = 231053
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdatePltStatusFailed
      GOTO ROLLBACKTran
   END

   GOTO Quit

ROLLBACKTran:
   ROLLBACK TRAN rdt_1650ExtUpd04
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   
END

GO