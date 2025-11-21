SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_839ExtInfo11                                    */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-08-20 1.0  yeekung    WMS-14630 Created                         */  
/* 2022-05-07 1.1  Yeekung    WMS-20134 fix pickzone nvarchar 1->10     */
/*                            (yeekung01)                               */
/* 2022-04-20 1.2  YeeKung    WMS-19311 Add Data capture (yeekung01)    */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839ExtInfo11] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,       
   @nAfterStep   INT,    
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), --(yeekun01) 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @nActQty      INT,
   @nSuggQTY     INT,
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30), 
   @cExtendedInfo NVARCHAR(20) OUTPUT, 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  

   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  

   IF @nStep IN ( 3) OR @nAfterStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Get PickHeader info  
         SELECT TOP 1  
            @cOrderKey = OrderKey,  
            @cLoadKey = ExternOrderKey,  
            @cZone = Zone  
         FROM dbo.PickHeader WITH (NOLOCK)  
         WHERE PickHeaderKey = @cPickSlipNo  

         -- Cross dock PickSlip  
         IF @cZone IN ('XD', 'LB', 'LP')  
         BEGIN
            SELECT TOP 1 @cID = PD.ID
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND  ( (@cPickZone = '') OR (LOC.PickZone = @cPickZone))
            AND   PD.QTY > 0  
            AND   PD.Status <> '4'  
            AND   PD.Status < @cPickConfirmStatus  
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            ORDER BY 1
         END

         -- Discrete PickSlip  
         ELSE IF @cOrderKey <> ''
         BEGIN
            SELECT TOP 1 @cID = PD.ID
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
            AND  ( (@cPickZone = '') OR (LOC.PickZone = @cPickZone))
            AND   PD.QTY > 0  
            AND   PD.Status <> '4'  
            AND   PD.Status < @cPickConfirmStatus  
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            ORDER BY 1
         END

         -- Conso PickSlip  
         ELSE IF @cLoadKey <> '' 
         BEGIN
            SELECT TOP 1 @cID = PD.ID
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey    
            AND  ( (@cPickZone = '') OR (LOC.PickZone = @cPickZone))
            AND   PD.QTY > 0  
            AND   PD.Status <> '4'  
            AND   PD.Status < @cPickConfirmStatus  
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            ORDER BY 1
         END
         -- Custom PickSlip  
         ELSE  
         BEGIN  
            SELECT TOP 1 @cID = PD.ID
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
            AND  ( (@cPickZone = '') OR (LOC.PickZone = @cPickZone))
            AND   PD.QTY > 0  
            AND   PD.Status <> '4'  
            AND   PD.Status < @cPickConfirmStatus  
            AND   PD.LOC = @cLOC
            AND   PD.SKU = @cSKU
            ORDER BY 1
         END  

         SET @cExtendedInfo = 'ID      : ' + @cID
      END
      IF @nInputKey = 0
      BEGIN
         SET @cExtendedInfo='KeyIn F For FullCase'
      END
   END
   IF @nStep IN ( 7,8)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cExtendedInfo='KeyIn F For FullCase'
      END
   END
  
QUIT:  

GO