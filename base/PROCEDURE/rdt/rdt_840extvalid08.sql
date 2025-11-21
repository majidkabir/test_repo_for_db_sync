SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtValid08                                   */
/* Purpose: Validate the sostatus                                       */
/*          Change from rdt_840ExtValid05                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-05-11 1.0  YeeKung    WMS-13323 Created                         */
/* 2021-04-16 1.1  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james01)                                 */
/* 2021-04-01 1.2  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2023-07-27 1.3  James      WMS-23192 Add orders status check in      */
/*                            step 1, 3, & 4 (james02)                  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtValid08] (
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
            SET @nErrNo = 152051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Track No'
            GOTO Fail
         END

         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PD.Orderkey
                     JOIN dbo.Loc L WITH (NOLOCK) ON L.Loc = PD.Loc
                     WHERE PD.OrderKey = @cOrderKey
                     AND O.SOStatus IN ( 'PENDPACK', 'HOLD','PENDCANC') )
         BEGIN
            SET @nErrNo = 152052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV Orders'
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
            SET @nErrNo = 152053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Track No'
            GOTO Fail
         END

         --SELECT @cOrd_TrackingNo = UserDefine04
         SELECT @cOrd_TrackingNo = TrackingNo   -- (james01)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey
         AND   StorerKey = @cStorerKey

         IF ISNULL( @cOrd_TrackingNo, '') <> '' AND ( @cOrd_TrackingNo <> @cTrackNo)
         BEGIN
            SET @nErrNo = 152054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Track No'
            GOTO Fail
         END
      END
   END

   IF @nStep IN ( 1, 3, 4)
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
         IF EXISTS (SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   (SOStatus IN ( 'PENDPACK', 'HOLD','PENDCANC') OR [STATUS] = 'CANC'))
         BEGIN
            SET @nErrNo = 152055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV Orders'
            GOTO Fail
         END
   	END
   END
Fail:

GO