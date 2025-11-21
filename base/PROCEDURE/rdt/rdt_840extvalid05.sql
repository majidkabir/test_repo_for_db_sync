SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840ExtValid05                                   */
/* Purpose: Validate the tracking no.                                   */
/*          If track# scanned is diff from orders.userdefine04, prompt  */
/*          error.                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-12-06 1.1  James      WMS-11373 Split from rdt_840ExtValid05    */
/*                            Add check loc type (james01)              */
/* 2021-04-01 1.2  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2021-04-16 1.3  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james02)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid05] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cTrackNo                  NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nCartonNo                 INT,
   @cCtnType                  NVARCHAR( 10),
   @cCtnWeight                NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,      
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cOrd_TrackingNo      NVARCHAR( 20)
   DECLARE @cFacility            NVARCHAR( 5)

   SET @nErrNo = 0

   SELECT @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   --After scan order to check if LOC only exists LocationType in ('DYNPICKP','DYNPPICK') then able to packing .
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.Loc = LOC.Loc)
                     WHERE PD.OrderKey = @cOrderKey
                     AND   PD.[Status] <> '4'
                     AND   PD.Qty > 0
                     AND   LOC.LocationType NOT IN ('DYNPICKP','DYNPPICK')
                     AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 147001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Track No'
            GOTO Fail
         END
      END   
   END
   
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF ISNULL( @cTrackNo, '') = ''
         BEGIN
            SET @nErrNo = 147002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Track No'
            GOTO Fail
         END
                  
         --SELECT @cOrd_TrackingNo = UserDefine04
         SELECT @cOrd_TrackingNo = TrackingNo   -- (james02)
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderkey
         AND   StorerKey = @cStorerKey

         IF ISNULL( @cOrd_TrackingNo, '') <> '' AND ( @cOrd_TrackingNo <> @cTrackNo)
         BEGIN
            SET @nErrNo = 147003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Track No'
            GOTO Fail
         END
      END
   END

Fail:

GO