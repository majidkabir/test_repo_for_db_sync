SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835ExtVal01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate pallet id                                          */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-04-2019  1.0  James       WMS8709.Created                         */
/* 19-07-2019  1.1  James       Move check overpack to step2 (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_835ExtVal01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @tExtValidate  VariableTable READONLY, 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cInvalidPS     NVARCHAR( 1)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @nPackQTY       INT
   DECLARE @nPickQTY       INT

   SET @cInvalidPS = '0'

   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tExtValidate WHERE Variable = '@cDocValue'
   SELECT @cID = Value FROM @tExtValidate WHERE Variable = '@cPltValue'

   SELECT @cZone = Zone, 
          @cLoadKey = ExternOrderKey,
          @cPH_OrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo  

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Get pickheader info
         DECLARE @cChkPickSlipNo NVARCHAR( 10)
         SELECT TOP 1
            @cChkPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Validate pickslip no
         IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
         BEGIN
            SET @nErrNo = 139051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PS#
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo 
                     AND   STATUS = '9')
         BEGIN
            SET @nErrNo = 139053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Pack Confirm
            GOTO Quit
         END

         -- Calc pack QTY
         SET @nPackQTY = 0
         SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
         FROM PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo

         -- conso picklist   
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
         BEGIN    
            -- Calc pick QTY
            SET @nPickQTY = 0
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.Status <> '4'
         END
         -- Discrete PickSlip
         ELSE IF ISNULL(@cPH_OrderKey, '') <> '' 
         BEGIN
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cPH_OrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.Status <> '4'
         END
         ELSE
         BEGIN
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.Status <> '4'
         END

         IF ( @nPackQTY > 0) AND ( @nPackQTY >= @nPickQTY)
         BEGIN
            SET @nErrNo = 139053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- conso picklist   
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
         BEGIN    
            IF NOT EXISTS ( SELECT 1 
               FROM dbo.PickHeader PH (NOLOCK)     
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)    
               JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND PD.Status < @cPickConfirmStatus -- Not yet picked    
                  AND PD.ID = @cID)
               SET @cInvalidPS = '1'
         END    
         ELSE  -- discrete picklist    
         BEGIN    
            IF ISNULL(@cPH_OrderKey, '') <> '' 
            BEGIN  
               IF NOT EXISTS ( SELECT 1 
                  FROM dbo.PickHeader PH (NOLOCK)     
                  INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
                  WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND   PD.Status < @cPickConfirmStatus -- Not yet picked    
                  AND   PD.ID = @cID)
               SET @cInvalidPS = '1'      
            END   
            ELSE
            BEGIN
               IF NOT EXISTS ( SELECT 1 
                  FROM dbo.PickHeader PH (NOLOCK)     
                  INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey  
                  INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)      
                  WHERE PH.PickHeaderKey = @cPickSlipNo    
                  AND   PD.Status < @cPickConfirmStatus -- Not yet picked    
                  AND   PD.ID = @cID)     
               SET @cInvalidPS = '1'       
            END   
         END 

         IF @cInvalidPS = '1'
         BEGIN
            SET @nErrNo = 139054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID NOT IN PSNO
            GOTO Quit
         END

         -- Calc pack QTY
         SET @nPackQTY = 0
         SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
         FROM PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND DROPID = @cID

         -- conso picklist   
         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
         BEGIN    
            -- Calc pick QTY
            SET @nPickQTY = 0
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.StorerKey = @cStorerKey
               AND PD.Status = @cPickConfirmStatus
               AND PD.ID = @cID
         END
         -- Discrete PickSlip
         ELSE IF ISNULL(@cPH_OrderKey, '') <> '' 
         BEGIN
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cPH_OrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.Status = @cPickConfirmStatus
               AND PD.ID = @cID
         END
         ELSE
         BEGIN
            SELECT @nPickQTY = ISNULL( SUM( QTY), 0)
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.StorerKey = @cStorerKey
               AND PD.Status = @cPickConfirmStatus
               AND PD.ID = @cID
         END

         IF ( @nPackQTY > 0) AND ( @nPackQTY >= @nPickQTY)
         BEGIN
            SET @nErrNo = 139055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
            GOTO Quit
         END
      END
   END

   Quit:
END

GO