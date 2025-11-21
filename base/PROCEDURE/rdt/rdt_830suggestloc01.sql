SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************/  
/* Store procedure: rdt_830SuggestLOC01                                          */  
/* Copyright      : LFLogistics                                                  */  
/*                                                                               */  
/* Purpose: Suggest pick LOC                                                     */  
/*                                                                               */  
/* Date        Rev  Author      Purposes                                         */  
/* 2018-06-01  1.0  James       WMS5005 - Created                                */  
/* 2020-01-22  1.1  YeeKung     WMS15995 Add Pickzone (yeekung01)                */  
/*********************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_830SuggestLOC01]  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15),  
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10), 
   @cLOC          NVARCHAR( 10),  
   @cSuggLOC      NVARCHAR( 10) OUTPUT,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSKU2Pick      NVARCHAR( 20),  
           @cSKU           NVARCHAR( 20),  
           @cZone          NVARCHAR( 10),  
           @cOrderKey      NVARCHAR( 10)  
   SET @cSuggLOC = ''  
  
   IF @nStep = 2  
      SET @cSKU = ''  
   ELSE  
      SELECT @cSKU = V_SKU FROM rdt.rdtMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
  
   CREATE TABLE #LOC (  
      RowRef      INT IDENTITY(1,1) NOT NULL,  
      OrderKey    NVARCHAR( 10)  NULL,  
      SKU         NVARCHAR( 20)  NULL,  
      LOC         NVARCHAR( 10)  NULL)  
  
   SELECT   
      @cZone = Zone,   
      @cOrderKey = OrderKey  
   FROM dbo.PickHeader WITH (NOLOCK)       
   WHERE PickHeaderKey = @cPickSlipNo    
  
   -- Insert all the exact matched pickdetail into temp table  
   -- Retrieve all the pickdetail records that have same lot, loc & id   
   IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'   
   BEGIN
      IF @cPickZone<>''
         -- CrossDock PickSlip  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.RefKeyLookup Ref WITH (NOLOCK)   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (Ref.PickDetailKey = PD.PickDetailKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE Ref.PickslipNo = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility  
         AND   LOC.PickZone=@cPickZone
      ELSE
         -- CrossDock PickSlip  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.RefKeyLookup Ref WITH (NOLOCK)   
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (Ref.PickDetailKey = PD.PickDetailKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE Ref.PickslipNo = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility  
   END
   ELSE IF @cOrderKey = ''  
   BEGIN
      IF @cPickZone<>''
         -- Conso PickDetail  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.PickHeader PH (NOLOCK)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE PH.PickHeaderKey = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility 
         AND   LOC.PickZone=@cPickZone
      ELSE
         -- Conso PickDetail  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.PickHeader PH (NOLOCK)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE PH.PickHeaderKey = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility 
   END 
   ELSE 
   BEGIN 
      IF @cPickZone<>''
         -- Discrete PickSlip  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.PickHeader PH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE PH.PickHeaderKey = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility  
         AND   LOC.PickZone=@cPickZone
      ELSE
         -- Discrete PickSlip  
         INSERT INTO #LOC   
         (OrderKey, SKU, LOC)  
         SELECT PD.OrderKey, PD.SKU, PD.LOC  
         FROM dbo.PickHeader PH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = PD.LOC)  
         WHERE PH.PickHeaderKey = @cPickSlipNo  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.Status < '4' -- Not yet picked  
         AND   PD.QTY > 0  
         AND   LOC.Facility = @cFacility  
   END
  
   -- Nothing to pick, show error  
   IF @@ROWCOUNT = 0  
      GOTO Quit  
  
   IF NOT EXISTS ( SELECT 1 FROM #LOC WITH (NOLOCK) WHERE SKU = @cSKU)  
      SET @cSKU = ''  
  
   -- Found loc to pick, get 1st sku to pick order by sku with most loc to pick  
   SELECT TOP 1 @cSKU2Pick = SKU FROM #LOC WITH (NOLOCK)   
   WHERE ( ( @cSKU = '') OR ( SKU = @cSKU))  
   GROUP BY SKU   
   ORDER BY COUNT( Loc) DESC, SKU  
  
   -- Get 1 suggest loc order by loc from query above  
   SELECT TOP 1 @cSuggLOC = L1.LOC   
   FROM #LOC L1 WITH (NOLOCK)  
   JOIN dbo.LOC L2 WITH (NOLOCK) ON L1.LOC = L2.LOC  
   WHERE SKU = @cSKU2Pick  
   AND   L2.Facility = @cFacility  
   ORDER BY L2.LogicalLocation, L2.LOC  
  
Quit:  
BEGIN  
   IF @cSuggLOC = ''  
   BEGIN  
      -- after key in qty, nothing to pick anymore then back to prev screen  
      IF @nStep = 4  
         SET @nErrNo = -1  
      ELSE  
      BEGIN  
         SET @nErrNo = 124201  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Suggect Loc  
      END  
   END  
END  
  
END  

GO