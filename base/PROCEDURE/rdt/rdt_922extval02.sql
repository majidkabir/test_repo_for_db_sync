SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal02                                      */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.2  Ung        SOS278061.                                */
/* 2014-01-06 1.3  Ung        SOS299726 Build and close pallet check    */
/* 2014-10-01 1.4  Ung        SOS321796                                 */
/*                            Reorganize param                          */
/*                            Rename rdtVFSTTExtVal to rdt_922ExtVal02  */
/* 2016-11-13 1.5  James      Add SOStatus checking. Limit no of orders */
/*                            that can add into mboldetail (james01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15),
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3),
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40), 
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cNoOfOrdersAllowed  NVARCHAR( 5)
DECLARE @nOrderCount INT

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

   IF @cMBOLKey <> ''
   BEGIN
      -- (james01)
      SET @cNoOfOrdersAllowed = rdt.rdtGetConfig( @nFunc, 'NoOfOrdersAllowed', @cStorerKey)
      IF rdt.rdtIsValidQTY( @cNoOfOrdersAllowed, 0) = 0
         SET @cNoOfOrdersAllowed = '0'   

      -- Limit no of orders per mbol, 0 = no limit
      IF CAST( @cNoOfOrdersAllowed AS INT) > 0
      BEGIN
         SET @nOrderCount = 0
         SELECT @nOrderCount = Count (Orderkey)
         FROM dbo.MBOLDetail WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey

         IF @cNoOfOrdersAllowed < @nOrderCount + 1
         BEGIN
            SET @nErrNo = 84153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --Allow #OfOrds
            GOTO Quit
         END
      END
   END
END

Quit:


GO