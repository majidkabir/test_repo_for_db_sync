SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: rdt_922ExtVal15                                     */
/* Copyright      : Maersk                                              */
/* Customer       : Mattel                                              */
/*                                                                      */
/* Date       Rev    Author     Purposes                                */
/* 2024-12-03 1.0.0  PSJ036     UWP-28347 RITM7382535 Created           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_922ExtVal15] (
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
   IF @nStep = 4  -- DOOR, REFNO
   BEGIN
      IF @nInputKey = 1
      DECLARE 
         @cChkDoor          NVARCHAR(10) = '',
         @cChkTruckNo       NVARCHAR(10) = '',
         @cPlaceOfLoading   NVARCHAR(10) = ''
      
      -- get Place of Loading
      SELECT @cPlaceOfLoading = PlaceOfLoading,
            @cChkTruckNo    = Vessel  
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey
     
      -- Get door rdt.rdtScanToTruck
      IF @cMBOLKey  <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      
      ELSE IF @cLoadKey <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cLoadKey

      ELSE IF @cOrderKey <> '' 
         SELECT @cChkDoor = Door FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cOrderKey
       
      -- Check different door
      IF @cChkDoor <> '' AND @cChkDoor <> @cDoor
      BEGIN
         SET @nErrNo = 230701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Door rdt.rdtScanToTruck
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- RefNo1
         GOTO Quit
      END
     
     -- Check if RefNo is Empty ->  door (WS- test)
      IF  ISNULL(@cDoor,'') = ''
      BEGIN
         SET @nErrNo = 230702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Empty Door Entry
         GOTO Quit
      END

      -- Check different Place of loading
      IF @cPlaceOfLoading = '' OR @cPlaceOfLoading <> @cDoor
      BEGIN
         SET @nErrNo = 230703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Door MBOL.PlaceOfLoading
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- RefNo1
         GOTO Quit
      END
     
      -- Check if Vehicle No is Empty ->  cRefNo
      IF  ISNULL(@cRefNo,'') = ''
      BEGIN
         SET @nErrNo = 230704
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo,@cLangCode,'DSP') --Empty Vehicle Entry
         GOTO Quit
      END  
     
      -- Check different Vehicle No.
      IF @cChkTruckNo = '' OR @cChkTruckNo <> @cRefNo
      BEGIN
         SET @nErrNo = 230705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Vehicle MBOL.Vessel
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo2
         GOTO Quit
      END
   END
END

Quit:

GO