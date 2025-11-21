SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922CapPackInfo01                                */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-26 1.0  Ung        SOS317603 Default carton type             */
/************************************************************************/

CREATE PROC [RDT].[rdt_922CapPackInfo01] (
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
   @cPackInfo   NVARCHAR( 3)  OUTPUT,
   @cWeight     NVARCHAR( 10) OUTPUT,
   @cCube       NVARCHAR( 10) OUTPUT,
   @cCartonType NVARCHAR( 10) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Get CartonType
DECLARE @cChkCartonType NVARCHAR( 10) 
SET @cChkCartonType = ''
SELECT TOP 1 
   @cChkCartonType = CartonType 
FROM Storer WITH (NOLOCK)
   JOIN Cartonization WITH (NOLOCK) ON (Cartonization.CartonizationGroup = Storer.CartonGroup)
WHERE Storer.StorerKey = @cStorerKey
ORDER BY UseSequence

-- Default CartonType
IF @cChkCartonType <> ''
   SET @cCartonType = @cChkCartonType
   
-- Capture Weight and CartonType
SET @cPackInfo = 'WT'


GO