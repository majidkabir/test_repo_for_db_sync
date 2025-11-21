SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtITXSTTExtVal                                     */
/* Purpose: Validate Weight Cube                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.2  Ung        SOS300731 Created                         */
/* 2013-09-01 1.3  Chee       Bug Fix-Add Additional Parameters(Chee01) */
/************************************************************************/

CREATE PROC [RDT].[rdtITXSTTExtVal] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @cStorerKey  NVARCHAR( 15), 
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cLabelNo    NVARCHAR( 20),
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cPackInfo   NVARCHAR( 3) = '',
   @cWeight     NVARCHAR( 10) = '',  
   @cCube       NVARCHAR( 10) = '',  
   @cCartonType NVARCHAR( 10) = '',
   @cDoor       NVARCHAR( 10) = '',  -- (Chee01)
   @cRefNo      NVARCHAR( 40) = '')  -- (Chee01)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 922
BEGIN
   IF @nStep = 3
   BEGIN
      -- Check weight
      IF CHARINDEX( 'W', @cPackInfo) <> 0
      BEGIN
         DECLARE @nWeight FLOAT
         SET @nWeight = CAST( @cWeight AS FLOAT)
         
         IF NOT (@nWeight > 0 AND @nWeight <= 99)
         BEGIN
            SET @nErrNo = 84701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WGT OutOfRange
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Weight
            GOTO Fail
         END
      END
      
      -- Check cube
      IF CHARINDEX( 'C', @cPackInfo) <> 0
      BEGIN
         DECLARE @nCube FLOAT
         SET @nCube = CAST( @cCube AS FLOAT)

         IF NOT (@nCube > 0 AND @nCube <= 99)
         BEGIN
            SET @nErrNo = 84702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CubeOutOfRange
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Cube
            GOTO Fail
         END
      END
   END
END

/*
DECLARE @cDropID NVARCHAR(20)
DECLARE @cLocationCategory NVARCHAR(10)

SET @cDropID = ''
SET @cLocationCategory = ''

-- Get DropID info
SELECT 
   @cDropID = DropID.DropID, 
   @cLocationCategory = LOC.LocationCategory
FROM dbo.DropID WITH (NOLOCK)
   JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (DropID.DropID = DID.DropID)
   JOIN dbo.LOC WITH (NOLOCK) ON (DropID.DropLOC = LOC.LOC)
WHERE DID.ChildID = @cLabelNo

-- Update DropID
IF @cLocationCategory = 'STAGING'
   IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID AND Status <> '9')
   BEGIN
      UPDATE dbo.DropID SET
         Status = '9', 
         TrafficCop = NULL
      WHERE DropID = @cDropID
   END
*/

Quit:
Fail:

GO