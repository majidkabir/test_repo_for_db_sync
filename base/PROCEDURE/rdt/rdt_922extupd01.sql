SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtUpd01                                     */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.0  Ung        SOS278061.                                */
/* 2014-08-06 1.1  Ung        SOS317603 Add InputKey param              */
/* 2015-12-01 1.2  Ung        SOS358041 ExtendedUpdateSP reorg param    */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtUpd01] (
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

IF @nFunc = 922
BEGIN
   IF @nStep = 2 -- LabelNo/DropID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
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
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID AND Status <> '9')
            BEGIN
               UPDATE dbo.DropID SET
                  Status = '9', 
                  TrafficCop = NULL
               WHERE DropID = @cDropID
            END
         END
      END
   END
END

Quit:
Fail:

GO