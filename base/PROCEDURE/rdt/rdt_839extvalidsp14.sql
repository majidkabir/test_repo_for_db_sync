SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/    
/* Store procedure: rdt_839ExtValidSP14                                 */ 
/* Copyright      : Maersk                                              */ 
/* Purpose: Validate                                                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2023-12-06 1.0  Tony       WMS-24315. Created                        */    
/************************************************************************/    
CREATE   PROC [RDT].[rdt_839ExtValidSP14] (    
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cFacility    NVARCHAR( 5) ,   
   @cStorerKey   NVARCHAR( 15),   
   @cType        NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cPickZone    NVARCHAR( 10),    
   @cDropID      NVARCHAR( 20),   
   @cLOC         NVARCHAR( 10),   
   @cSKU         NVARCHAR( 20),   
   @nQTY         INT,           
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),     
   @nErrNo       INT           OUTPUT,   
   @cErrMsg      NVARCHAR(250) OUTPUT    
)    
AS    
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
    
IF @nFunc = 839    
BEGIN
  DECLARE @cOrderKey       NVARCHAR( 10) = ''
          ,@cLoadKey       NVARCHAR( 10) = '' 
          ,@cZone          NVARCHAR( 10) = ''
          ,@cPSType        NVARCHAR( 10) = ''
          ,@nMultiFlag     INT = 0
          
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   SELECT @cZone = Zone, 
          @cLoadKey = LoadKey,
          @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get PickSlip type      
   IF @@ROWCOUNT = 0
      SET @cPSType = 'CUSTOM'
   ELSE
   BEGIN
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SET @cPSType = 'XD'
      ELSE IF @cOrderKey = ''
         SET @cPSType = 'CONSO'
      ELSE 
         SET @cPSType = 'DISCRETE'
   END  
 
   -- Validate SKU And QTY
   IF @nStep = 3   
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN
         IF @cSKU IN ('','99')
            GOTO QUIT

         --CrossDock
         IF @cPSType = 'XD' AND EXISTS(SELECT 1
                     FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                        JOIN dbo.Orders O WITH (NOLOCK)  ON PD.OrderKey = O.OrderKey
                     WHERE RKL.PickSlipNo = @cPickSlipNo  
                     AND O.DocType = 'N')
         BEGIN
            IF @cPickZone = ''
            BEGIN
               SELECT @nMultiFlag = COUNT(1)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.PickDetailKey = RKL.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo 
                  AND PD.Dropid = @cDropID
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
                  AND Sku <> @cSKU
            END
            ELSE
            BEGIN
               SELECT @nMultiFlag = COUNT(1)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.PickDetailKey = RKL.PickDetailKey
                  JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
               WHERE RKL.PickSlipNo = @cPickSlipNo 
                  AND PD.Dropid = @cDropID
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
                  AND LOC.PickZone = @cPickZone
                  AND Sku <> @cSKU
            END

            IF @nMultiFlag > 0
            BEGIN
               SET @nErrNo = 209401    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No mix SKU     
               GOTO QUIT 
            END
         END

         --Consolidate 
         IF @cPSType = 'CONSO' AND EXISTS(SELECT 1
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                          JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) 
                     WHERE LPD.LoadKey = @cLoadKey  
                     AND O.DocType = 'N')
         BEGIN
            IF @cPickZone = ''
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.Dropid = @cDropID
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
                  AND Sku <> @cSKU
            END
            ELSE
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                  JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.Dropid = @cDropID
                  AND LOC.PickZone = @cPickZone
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
                  AND Sku <> @cSKU
            END
            IF @nMultiFlag > 0
            BEGIN
               SET @nErrNo = 209402    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No mix SKU     
               GOTO QUIT 
            END
         END

          --CUSTOM Pick slip 
         IF @cPSType = 'CUSTOM' AND EXISTS(SELECT 1
                     FROM  dbo.PickDetail PD WITH (NOLOCK)
                          JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) 
                     WHERE PD.PickSlipNo = @cPickSlipNo  
                     AND O.DocType = 'N')
         BEGIN
            IF @cPickZone = ''
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM  dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @cPickSlipNo   
                  AND PD.Dropid = @cDropID
                  AND Sku <> @cSKU
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
            END
            ELSE
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM  dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
               WHERE PD.PickSlipNo = @cPickSlipNo   
                  AND PD.Dropid = @cDropID
                  AND Sku <> @cSKU
                  AND PD.Status <> '4'
                  AND LOC.PickZone = @cPickZone
                  AND PD.Qty > 0
            END

            IF @nMultiFlag > 0
            BEGIN
               SET @nErrNo = 209403    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No mix SKU     
               GOTO QUIT 
            END
         END
         IF @cPSType = 'DISCRETE' AND EXISTS(SELECT 1
                     FROM  dbo.PickDetail PD WITH (NOLOCK)
                          JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey) 
                     WHERE PD.OrderKey = @cOrderKey  
                     AND O.DocType = 'N')
         BEGIN
            IF @cPickZone = ''
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM  dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cOrderKey  
                  AND PD.Dropid = @cDropID
                  AND Sku <> @cSKU
                  AND PD.Status <> '4'
                  AND PD.Qty > 0
            END
            ELSE
            BEGIN
               SELECT @nMultiFlag = COUNT(1) 
               FROM  dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC
               WHERE PD.OrderKey = @cOrderKey    
                  AND PD.Dropid = @cDropID
                  AND Sku <> @cSKU
                  AND PD.Status <> '4'
                  AND LOC.PickZone = @cPickZone
                  AND PD.Qty > 0
            END

            IF @nMultiFlag > 0
            BEGIN
               SET @nErrNo = 209404    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No mix SKU     
               GOTO QUIT 
            END
         END
      END  
   END  
END    
    
QUIT:    

GO