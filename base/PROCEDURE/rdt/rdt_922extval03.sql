SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal03                                     */
/* Purpose: Validate LabelNo in MBOL                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-05-25 1.0  Chee       SOS#309892 Created                        */
/* 2014-10-01 1.1  Ung        SOS321796                                 */
/*                            Reorganize param                          */
/*                            Rename rdtANFSTTExtVal to rdt_922ExtVal03 */
/* 2016-11-13 1.2  James      Add SOStatus checking. Limit no of orders */
/*                            that can add into mboldetail (james01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal03] (
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
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cOrderType NVARCHAR(10)
DECLARE @cNoOfOrdersAllowed  NVARCHAR( 5)
DECLARE @nOrderCount INT

IF @nFunc = 922
BEGIN
   IF @nStep = 2
   BEGIN
      SELECT @cOrderType = [Type]
      FROM Orders O WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey

      IF @cOrderType <> 'CHDORD'
         RETURN

      IF NOT EXISTS(SELECT 1 FROM DropID D (NOLOCK)
                    JOIN DropIDDetail DD (NOLOCK) on (D.DropID = DD.DropID)
                    WHERE DD.UserDefine01 = @cMBOLKey
                      AND DD.ChildID = @cLabelNo)
      BEGIN
         SET @nErrNo = 87151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLabelNo
         GOTO Quit
      END

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
            SET @nErrNo = 87152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   --Allow #OfOrds
            GOTO Quit
         END
      END
   END -- IF @nStep = 2
END -- IF @nFunc = 922

Quit:

GO