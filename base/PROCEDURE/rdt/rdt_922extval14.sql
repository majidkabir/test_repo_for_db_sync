SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtVal14                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-07-30 1.0  Jackc      FCR-619 Created                           */
/************************************************************************/

CREATE   PROC rdt.rdt_922ExtVal14 (
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

SET @nErrNo = 0

IF @nFunc = 922 -- Scan to truck
BEGIN
   IF @nStep = 4  -- Ref No
   BEGIN
      IF @nInputKey = 1
      BEGIN
         DECLARE  @cCheckRefNo      NVARCHAR(3),
                  @nCheckRefNo1     INT = 0,
                  @nCheckRefNo2     INT = 0
         SET @cCheckRefNo = rdt.RDTGetConfig( @nFunc, 'REFNOREQ', @cStorerKey)
         IF @cCheckRefNo = '0'  
            SET @cCheckRefNo = ''

         IF @cCheckRefNo <> ''
         BEGIN
            SET @nCheckRefNo1 = CHARINDEX('1', @cCheckRefNo)
            SET @nCheckRefNo2 = CHARINDEX('2', @cCheckRefNo)
         END

         IF @nCheckRefNo1 > 0 AND ISNULL(@cDoor,'') = ''
         BEGIN
            SET @nErrNo = 220501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo Required
            GOTO Quit 
         END

         IF @nCheckRefNo2 > 0 AND ISNULL(@cRefNo,'') = ''
         BEGIN
            SET @nErrNo = 220502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo2 Required
            GOTO Quit 
         END

      END -- inputkey =1
   END -- step4
END

Quit:


GO