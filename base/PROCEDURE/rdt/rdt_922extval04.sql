SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal04                                     */
/* Purpose: Custom validate MBOL ship, truck no                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-04-25 1.0  Ung        SOS308184                                 */
/* 2014-10-01 1.1  Ung        SOS321796                                 */
/*                            Reorganize param                          */
/*                            Rename rdtDSGSTTExtVal to rdt_922ExtVal04 */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtVal04] (
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

IF @nFunc = 922 -- Scan to truck
BEGIN
   
   IF @nStep = 1  -- MBOL/LOAD/ORDER
   BEGIN
      IF @cMBOLKey <> ''
      BEGIN
         -- Get MBOL info
         DECLARE @cChkMBOLStatus NVARCHAR(10)
         DECLARE @cUserDefine09  NVARCHAR(10)
         SELECT 
            @cChkMBOLStatus = [Status], 
            @cUserDefine09 = UserDefine09
         FROM dbo.MBOL WITH (NOLOCK) 
         WHERE MBOLKey = @cMBOLKey
         
         -- Check MBOL shipped
         IF @cUserDefine09 <> 'BYPASS' AND @cChkMBOLStatus = '9'
         BEGIN
            SET @nErrNo = 87001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
            GOTO Quit
         END
      END
   END
   
   IF @nStep = 4  -- Door/LabelNo
   BEGIN
      IF @cDoor = ''
      BEGIN
         SET @nErrNo = 87002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Truck No
         GOTO Quit
      END
         
      -- Check TruckNo valid
      IF NOT EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'TRUCKNO' AND StorerKey = @cStorerKey AND Code = @cDoor)
      BEGIN
         SET @nErrNo = 87003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad TruckNo
         GOTO Quit
      END
   END
END
Quit:


GO