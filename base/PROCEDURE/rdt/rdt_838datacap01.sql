SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_838DataCap01                                    */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 30-09-2019 1.0  Ung         WMS-10729 Created                        */  
/* 25-03-2020 1.1  Ung         INC1090884 Add CaseID filter             */  
/* 14-02-2022 1.2  YeeKung     WMS-18323 Add params (yeekung01)         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_838DataCap01] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15),  
   @cPickSlipNo      NVARCHAR( 10),  
   @cFromDropID      NVARCHAR( 20),  
   @nCartonNo        INT,  
   @cLabelNo         NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @nQTY             INT,  
   @cUCCNo           NVARCHAR( 20),  
   @cCartonType      NVARCHAR( 10),  
   @cCube            NVARCHAR( 10),  
   @cWeight          NVARCHAR( 10),  
   @cRefNo           NVARCHAR( 20),  
   @cSerialNo        NVARCHAR( 30),  
   @nSerialQTY       INT,  
   @cOption          NVARCHAR( 1),  
   @cPackDtlRefNo    NVARCHAR( 20),   
   @cPackDtlRefNo2   NVARCHAR( 20),   
   @cPackDtlUPC      NVARCHAR( 30),   
   @cPackDtlDropID   NVARCHAR( 20),   
   @cPackData1       NVARCHAR( 30)  OUTPUT,   
   @cPackData2       NVARCHAR( 30)  OUTPUT,   
   @cPackData3       NVARCHAR( 30)  OUTPUT,  
   @cPackLabel1      NVARCHAR( 20)  OUTPUT, --(yeekung01)  
   @cPackLabel2      NVARCHAR( 20)  OUTPUT, --(yeekung01)  
   @cPackLabel3      NVARCHAR( 20)  OUTPUT, --(yeekung01)  
   @cPackAttr1       NVARCHAR( 1)   OUTPUT, --(yeekung01)  
   @cPackAttr2       NVARCHAR( 1)   OUTPUT, --(yeekung01)  
   @cPackAttr3       NVARCHAR( 1)   OUTPUT, --(yeekung01)  
   @cDataCapture     NVARCHAR( 1)   OUTPUT,   
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount   INT  
   DECLARE @cOrderKey   NVARCHAR( 10) = ''  
   DECLARE @cLoadKey    NVARCHAR( 10) = ''  
   DECLARE @cZone       NVARCHAR( 18) = ''  
   DECLARE @cPrevPackData1 NVARCHAR( 30) = ''  
   DECLARE @cPickStatus NVARCHAR(1)  
  
   -- Storer config  
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)  
  
   -- Get PickHeader info  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  
  
   SET @cPrevPackData1 = @cPackData1  
   SET @cPackData1 = ''  
   SET @cPackData2 = ''  
   SET @cPackData3 = ''  
  
   -- Cross dock PickSlip  
   IF @cZone IN ('XD', 'LB', 'LP')  
      SELECT @cPackData1 = LA.Lottable01  
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)  
      WHERE RKL.PickSlipNo = @cPickSlipNo  
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND PD.QTY > 0  
         AND PD.Status = @cPickStatus  
         AND PD.Status <> '4'  
         AND PD.CaseID = ''  
      GROUP BY LA.Lottable01  
      ORDER BY CASE WHEN LA.Lottable01 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable  
  
   -- Discrete PickSlip  
   ELSE IF @cOrderKey <> ''  
      SELECT @cPackData1 = LA.Lottable01  
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)  
      WHERE PD.OrderKey = @cOrderKey  
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND PD.QTY > 0  
         AND PD.Status = @cPickStatus  
         AND PD.Status <> '4'  
         AND PD.CaseID = ''  
      GROUP BY LA.Lottable01  
      ORDER BY CASE WHEN LA.Lottable01 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable  
                 
   -- Conso PickSlip  
   ELSE IF @cLoadKey <> ''  
      SELECT @cPackData1 = LA.Lottable01  
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
         JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)  
      WHERE LPD.LoadKey = @cLoadKey    
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND PD.QTY > 0  
         AND PD.Status = @cPickStatus  
         AND PD.Status <> '4'  
         AND PD.CaseID = ''  
      GROUP BY LA.Lottable01  
      ORDER BY CASE WHEN LA.Lottable01 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable  
     
   -- Custom PickSlip  
   ELSE  
      SELECT @cPackData1 = LA.Lottable01  
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND PD.QTY > 0  
         AND PD.Status = @cPickStatus  
         AND PD.Status <> '4'  
         AND PD.CaseID = ''  
      GROUP BY LA.Lottable01  
      ORDER BY CASE WHEN LA.Lottable01 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable  
  
   SET @nRowCount = @@ROWCOUNT  
     
   IF @nRowCount = 1  
      SET @cDataCapture = '0' -- Auto default, don't need to capture  
   ELSE IF @nRowCount > 1  
   BEGIN  
      SET @cDataCapture = '1' -- need to capture  
      IF @cPackData1 <> @cPrevPackData1  
         SET @cPackData1 = '' -- PackData changed, force key-in  

      SET @cPackAttr1=''
      SET @cPackAttr2=''
      SET @cPackAttr3=''
  
      SET @cPackLabel1='Data 1:'--(yeekung01)  
      SET @cPackLabel2='Data 2:'--(yeekung01)  
      SET @cPackLabel3='Data 3:'--(yeekung01)  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1    
   END  
END  

GO