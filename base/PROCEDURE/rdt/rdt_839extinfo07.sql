SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_839ExtInfo07                                    */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-04-19 1.0  YeeKUng    WMS-16839 created                         */
/* 2022-05-07 1.1  Yeekung    WMS-20134 fix pickzone nvarchar 1->10     */
/*                            (yeekung01)                               */
/* 2022-04-20 1.2  YeeKung    WMS-19311 Add Data capture (yeekung02)    */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839ExtInfo07] (  
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
   @cPickZone    NVARCHAR( 10), --(yeekung01)  
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
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
   DECLARE @ccurPD      CURSOR
   DECLARE @nPD_Qty     INT

   SET @cExtendedInfo = ''

   IF @nStep IN (3) OR @nAfterStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN

          DECLARE @nCtnQty INT,@nPQTY INT

          DECLARE @cOrderKey NVARCHAR(20),@cLoadKey nvarchar(20),@cZone NVARCHAR(20),@nPUOM_Div INT ,@cPUOM INT

          SELECT @cPUOM=V_UOM
          FROM rdt.RDTMOBREC (NOLOCK)
          WHERE mobile=@nMobile

          SELECT TOP 1      
            @cOrderKey = OrderKey,      
            @cLoadKey = ExternOrderKey,      
            @cZone = Zone      
         FROM dbo.PickHeader WITH (NOLOCK)      
         WHERE PickHeaderKey = @cPickSlipNo  

         -- Cross dock PickSlip      
         IF @cZone IN ('XD', 'LB', 'LP')      
         BEGIN      
            IF @cPickZone = ''      
               SELECT TOP 1      
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)                     
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)      
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)    
               WHERE RKL.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU
            ELSE      
               SELECT TOP 1      
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)       
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)      
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)      
               WHERE RKL.PickSlipNo = @cPickSlipNo      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU  
         END      
         
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
               SELECT     
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)       
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)   
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)    
               WHERE PD.OrderKey = @cOrderKey      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU        
            ELSE      
               SELECT      
                 @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)   
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)    
               WHERE PD.OrderKey = @cOrderKey      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU       
         END      
                        
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
               SELECT      
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)     
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)     
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)  
               WHERE LPD.LoadKey = @cLoadKey             
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU      
            ELSE      
               SELECT       
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)     
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)  
               WHERE LPD.LoadKey = @cLoadKey        
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU     
         END     
            
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
               SELECT      
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)   
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)     
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU      
            ELSE      
               SELECT     
                  @nPUOM_Div= CAST(  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.CaseCNT  
                        WHEN '3' THEN Pack.InnerPack  
                        WHEN '6' THEN Pack.QTY  
                        WHEN '1' THEN Pack.Pallet  
                        WHEN '4' THEN Pack.OtherUnit1  
                        WHEN '5' THEN Pack.OtherUnit2  
                     END AS INT)   
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)     
                  INNER JOIN dbo.Pack Pack (nolock) ON (PD.PackKey = Pack.PackKey)  
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < '5'      
                  AND LOC.LOC=@cLOC
                  AND PD.SKU=@cSKU      
         END      

         SET @cExtendedInfo = 'CTN:'+ CAST((@nSuggQTY/@nPUOM_Div) AS NVARCHAR(5)) +'|' +'PCS:'+CAST((@nSuggQTY%@nPUOM_Div) AS NVARCHAR(5))
      END
   END
  
QUIT:  
 

GO