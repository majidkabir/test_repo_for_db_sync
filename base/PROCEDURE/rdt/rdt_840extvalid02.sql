SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid02                                   */
/* Purpose: Validate the tracking no.                                   */
/*          If track# scanned is diff from orders.userdefine04, prompt  */
/*          error.                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-03-03 1.0  James      SOS365177 Created                         */
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2021-04-16 1.2  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james01)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid02] (
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

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF ISNULL( @cTrackNo, '') = ''
         BEGIN
            SET @nErrNo = 96951
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
            SET @nErrNo = 96952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Track No'
            GOTO Fail
         END
      END
   END

Fail:

GO