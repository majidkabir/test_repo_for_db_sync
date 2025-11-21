SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtHnMExtVal02                                      */
/* Purpose: Validate Orders ShipperKey is the same with                 */
/*          Orders ShipperKey of the first scanned in order             */
/*          with same MBOL Key                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-03-31 1.0  James      SOS305334 Created                         */
/* 2018-03-05 1.1  Ung        Change hardcode message to message        */
/* 2021-04-16 1.2  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james01)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdtHnMExtVal02] (
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @cStorerKey      NVARCHAR( 15), 
   @cMBOLKey        NVARCHAR( 10), 
   @cOrderKey       NVARCHAR( 10), 
   @cTrackNo        NVARCHAR( 18), 
   @nValid          INT            OUTPUT,  
   @nErrNo          INT            OUTPUT,  
   @cErrMsg         NVARCHAR( 20)  OUTPUT,  
   @cErrMsg1        NVARCHAR( 20)  OUTPUT,  
   @cErrMsg2        NVARCHAR( 20)  OUTPUT,  
   @cErrMsg3        NVARCHAR( 20)  OUTPUT,  
   @cErrMsg4        NVARCHAR( 20)  OUTPUT,  
   @cErrMsg5        NVARCHAR( 20)  OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cTemp_OrderKey    NVARCHAR( 20), 
           @cShipperKey       NVARCHAR( 15), 
           @cTemp_ShipperKey  NVARCHAR( 15) 
   
   SET @nValid = 1
   SET @cErrMsg1 = ''      
   SET @cErrMsg2 = ''
   SET @cErrMsg3 = ''
   SET @cErrMsg4 = ''
   SET @cErrMsg5 = ''

   IF ISNULL( @cMBOLKey, '') = '' OR ISNULL( @cTrackNo, '') = ''
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END

   SELECT TOP 1 @cTemp_OrderKey = OrderKey 
   FROM dbo.MBOLDETAIL WITH (NOLOCK) 
   WHERE MbolKey = @cMBOLKey

   -- If it is the first orderkey to scan
   IF ISNULL( @cTemp_OrderKey, '') = ''
   BEGIN
      SET @nValid = 1
      GOTO Quit
   END

   SELECT @cTemp_ShipperKey = ShipperKey
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cTemp_OrderKey

   SELECT @cShipperKey = ShipperKey
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   --AND   UserDefine04 = @cTrackNo
   AND   TrackingNo = @cTrackNo  -- (james01)
   AND   [Status] < '9'
   
   IF ISNULL( @cTemp_ShipperKey, '') <> ISNULL( @cShipperKey, '')
   BEGIN
      SET @cErrMsg1 = rdt.rdtgetmessage( 120551, @cLangCode, 'DSP') --DIFF COURIER CODE !
      SET @cErrMsg5 = rdt.rdtgetmessage( 120552, @cLangCode, 'DSP') --PRESS ESC TO GO BACK

      SET @nValid = 0
      GOTO Quit
   END


Quit:

Fail:

GO