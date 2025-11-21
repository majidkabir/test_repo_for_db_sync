SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show picked qty/total qty of the current loc                */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2017-12-27 1.0  James   WMS3621. Created                             */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862ExtInfo03] (
    @nMobile         INT 
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nAfterStep      INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5) 
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggestedLOC   NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME     
   ,@nTaskQTY        INT          
   ,@nPQTY           INT          
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1) 
   ,@cExtendedInfo   NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTtl_Qty2Pick     INT,
           @nTtl_PickedQty    INT,
           @cZone             NVARCHAR( 18),
           @cPH_OrderKey      NVARCHAR( 10)  

   IF @nFunc = 862 -- Pick by ID
   BEGIN
      IF @nStep = 2 AND @nAfterStep = 6
      BEGIN
         SET @nTtl_Qty2Pick = 0
         SET @nTtl_PickedQty = 0

         SELECT @cZone = Zone, @cPH_OrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)   
         WHERE PickHeaderKey = @cPickSlipNo  

         If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'  
         BEGIN  
            SELECT @nTtl_Qty2Pick = ISNULL( SUM( PD.Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON ( RPL.PickDetailKey = PD.PickDetailKey)
            WHERE RPL.PickslipNo = @cPickSlipNo    
            AND   PD.Status < '9'
            AND   PD.LOC = @cLOC  

            SELECT @nTtl_PickedQty = ISNULL( SUM( PD.Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN RefKeyLookup RPL WITH (NOLOCK) ON ( RPL.PickDetailKey = PD.PickDetailKey)
            WHERE RPL.PickslipNo = @cPickSlipNo    
            AND   PD.Status = '5' -- Picked  
            AND   PD.LOC = @cLOC  
         END  
         ELSE  -- discrete picklist  
         BEGIN  
            IF ISNULL(@cPH_OrderKey, '') <> ''  
            BEGIN
               SELECT @nTtl_Qty2Pick = ISNULL( SUM( PD.Qty), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)   
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PH.OrderKey = PD.OrderKey)  
               WHERE PH.PickHeaderKey = @cPickSlipNo  
               AND   PD.Status < '9'
               AND   PD.LOC = @cLOC  

               SELECT @nTtl_PickedQty = ISNULL( SUM( PD.Qty), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)   
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PH.OrderKey = PD.OrderKey)  
               WHERE PH.PickHeaderKey = @cPickSlipNo  
               AND   PD.Status = '5' -- Picked  
               AND   PD.LOC = @cLOC  
            END
            ELSE
            BEGIN
               SELECT @nTtl_Qty2Pick = ISNULL( SUM( PD.Qty), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)     
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo  
               AND   PD.Status < '9'
               AND   PD.LOC = @cLOC  

               SELECT @nTtl_PickedQty = ISNULL( SUM( PD.Qty), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)     
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)    
               WHERE PH.PickHeaderKey = @cPickSlipNo  
               AND   PD.Status = '5' -- Picked  
               AND   PD.LOC = @cLOC  
            END
         END 

         SET @cExtendedInfo = 'LOC: ' + @cLOC + ' ' + RTRIM( CAST( @nTtl_PickedQty AS NVARCHAR( 4))) + '/' + CAST( @nTtl_Qty2Pick AS NVARCHAR( 4))
      END

      IF @nStep = 6 AND @nAfterStep = 2
      BEGIN
         SET @cExtendedInfo = @cPickSlipNo
      END

   END
Quit:


GO