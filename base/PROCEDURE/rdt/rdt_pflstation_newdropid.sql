SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PFLStation_NewDropID                            */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 24-06-2019 1.0  Ung         WMS-9372 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_PFLStation_NewDropID] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cDropID      NVARCHAR( 20) 
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Check DropID assigned
   IF EXISTS( SELECT 1
      FROM rdt.rdtPFLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND DropID = @cDropID)
   BEGIN
      SET @nErrNo = 140301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned
      GOTO Quit
   END

   -- Save assign
   UPDATE rdt.rdtPFLStationLog SET
      DropID = @cDropID, 
      EditWho = SUSER_SNAME(), 
      EditDate = GETDATE()
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 140302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
      GOTO Quit
   END

Quit:

END

GO