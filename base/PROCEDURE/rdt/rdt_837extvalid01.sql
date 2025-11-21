SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_837ExtValid01                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Update pickdetail status                                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-04-27  1.0  James       WMS-13005. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_837ExtValid01]
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT, 
   @nInputKey      INT, 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cFromDropID    NVARCHAR( 20), 
   @cFromSKU       NVARCHAR( 20), 
   @nCartonNo      INT, 
   @cLabelNo       NVARCHAR( 20), 
   @cType          NVARCHAR( 10), 
   @cOption        NVARCHAR( 1),  
   @tExtValidate   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 10)
   DECLARE @nShipped    INT

   SET @nShipped = 0
   
   IF @nStep = 3  -- Confirm unpack
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            SELECT @cZone = Zone, 
                   @cLoadKey = ExternOrderKey,
                   @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)     
            WHERE PickHeaderKey = @cPickSlipNo  
            
            -- Cross Dock PickSlip   
            IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'  
            BEGIN
               IF NOT EXISTS ( SELECT 1 
                               FROM dbo.RefKeyLookup RKL WITH (NOLOCK) 
                               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) 
                               WHERE RKL.PickSlipNo = @cPickSlipNo 
                               AND   PD.StorerKey = @cStorerKey 
                               AND   PD.Status < '9')
                  SET @nShipped = 1
            END
            -- Discrete PickSlip
            ELSE IF ISNULL(@cOrderKey, '') <> '' 
            BEGIN
               IF NOT EXISTS ( SELECT 1
                               FROM dbo.PickDetail PD WITH (NOLOCK)  
                               WHERE PD.OrderKey = @cOrderKey 
                               AND   PD.StorerKey = @cStorerKey 
                               AND   PD.Status < '9')
                  SET @nShipped = 1
            END
            -- Conso PickSlip
            ELSE
            BEGIN
               IF NOT EXISTS ( SELECT 1
                               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                               JOIN dbo.PickDetail PD (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)   
                               WHERE LPD.LoadKey = @cLoadKey 
                               AND   PD.StorerKey = @cStorerKey 
                               AND   PD.Status < '9')
                  SET @nShipped = 1
            END
            -- Other Pickslip
            BEGIN
               IF NOT EXISTS ( SELECT 1
                               FROM dbo.PickDetail PD WITH (NOLOCK) 
                               WHERE PD.PickSlipNo = @cPickSlipNo 
                               AND   PD.StorerKey = @cStorerKey 
                               AND   PD.Status < '9')
                  SET @nShipped = 1
            END

            IF @nShipped = 1
            BEGIN
               SET @nErrNo = 151951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Orders Shipped
               GOTO Quit
            END
         END   -- @cOption
      END   -- @nInputKey
   END   -- @nStep




Quit:
END

GO