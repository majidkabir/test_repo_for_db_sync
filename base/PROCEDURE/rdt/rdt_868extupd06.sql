SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_868ExtUpd06                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Pack confirm when pick = pack                               */
/*                                                                      */
/* Called from: rdtfnc_PickAndPack                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-05-07 1.0  James      WMS-16960. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd06] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSumPackQTY       INT
   DECLARE @nSumPickQTY       INT
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @nNeedWeight       INT = 0
   DECLARE @cOrderGroup       NVARCHAR( 20)
   DECLARE @cShipperKey       NVARCHAR( 15)
   
   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 6
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cOrderKey = OrderKey
            FROM dbo.PICKHEADER WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo
               
            SELECT @cOrderGroup = OrderGroup, 
                     @cShipperKey = ShipperKey
            FROM dbo.ORDERS WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
               
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                        WHERE LISTNAME = 'UAOrder' 
                        AND   Short = @cOrderGroup 
                        AND   Long = @cShipperKey)
               SET @nNeedWeight = 1

            IF @nNeedWeight = 0
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                           WHERE LISTNAME = 'UAOrder' 
                           AND   ISNULL( Long, '') <> @cShipperKey) 
                  SET @nNeedWeight = 1
            END
            
            SELECT @cPickSlipNo = V_PickSlipNo
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey

            SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderKey
            AND   StorerKey = @cStorerKey

            IF @nSumPackQTY = @nSumPickQTY AND @nNeedWeight = 0
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  STATUS = '9'
               WHERE PickSlipNo = @cPickSlipNo
               SET @nErrNo = @@ERROR

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'
                  GOTO Quit
               END
            END
         END
      END

      IF @nStep = 7 -- Capture packinfo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cPickSlipNo = V_PickSlipNo
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey

            SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderKey
            AND   StorerKey = @cStorerKey

            IF @nSumPackQTY = @nSumPickQTY
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  STATUS = '9'
               WHERE PickSlipNo = @cPickSlipNo
               SET @nErrNo = @@ERROR

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:


GO