SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: rdt_922ExtInfo01                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-04-12 1.0  Ung        WMS-23190 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_922ExtInfo01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
   @cType           NVARCHAR( 1),
   @cMBOLKey        NVARCHAR( 10),
   @cLoadKey        NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cLabelNo        NVARCHAR( 20),
   @cPackInfo       NVARCHAR( 3),
   @cWeight         NVARCHAR( 10),
   @cCube           NVARCHAR( 10),
   @cCartonType     NVARCHAR( 10),
   @cDoor           NVARCHAR( 10),
   @cRefNo          NVARCHAR( 40),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 922 -- Scan to truck
BEGIN
   IF @nAfterStep = 4  -- DOOR, REFNO
   BEGIN
      DECLARE @cChkDoor NVARCHAR(10) = ''
      
      -- Get door
      IF @cMBOLKey  <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      
      ELSE IF @cLoadKey <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cLoadKey

      ELSE IF @cOrderKey <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      -- Check different door
      IF @cChkDoor <> ''
         SET @cExtendedInfo = @cChkDoor
   END
END

Quit:

GO