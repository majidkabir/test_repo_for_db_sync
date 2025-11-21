SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFSTTExtVal                                      */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.2  Ung        SOS278061.                                */
/* 2014-01-06 1.3  Ung        SOS299726 Build and close pallet check    */
/* 2017-02-27 1.4  TLTING     Variable Nvarchar                         */
/************************************************************************/

CREATE PROC [RDT].[rdtVFSTTExtVal] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   CHAR( 3), 
   @nStep       INT, 
   @cStorerKey  NVARCHAR( 15), 
   @cType       NCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cLabelNo    NVARCHAR( 20),
   @nErrNo      INT       OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nStep = 2  -- LabelNo/DropID
BEGIN
   DECLARE @cDropIDLoadKey NVARCHAR(10)
   SET @cDropIDLoadKey = ''
   
   -- Get DropID info
   SELECT 
      @cDropIDLoadKey = DropID.LoadKey
   FROM dbo.DropID WITH (NOLOCK)
      JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (DropID.DropID = DID.DropID)
   WHERE DID.ChildID = @cLabelNo
   
   -- Check built pallet 
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 84151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotBuiltPallet
      GOTO Quit
   END
   
   -- Check closed pallet
   IF @cDropIDLoadKey = ''
   BEGIN
      SET @nErrNo = 84152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotClosePallet
      GOTO Quit
   END
END

Quit:

GO