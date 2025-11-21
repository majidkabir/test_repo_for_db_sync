SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DataCap02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 16-11-2022 1.0  yeekung     WMS-18323 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838DataCap02] (
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
   @cPackData1        NVARCHAR( 30)  OUTPUT,
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
      SELECT @cPackData1 = LA.Lottable03
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
      GROUP BY LA.Lottable03
      ORDER BY CASE WHEN LA.Lottable03 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
      SELECT @cPackData1 = LA.Lottable03
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.QTY > 0
         AND PD.Status = @cPickStatus
         AND PD.Status <> '4'
         AND PD.CaseID = ''
      GROUP BY LA.Lottable03
      ORDER BY CASE WHEN LA.Lottable03 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
      SELECT @cPackData1 = LA.Lottable03
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
      GROUP BY LA.Lottable03
      ORDER BY CASE WHEN LA.Lottable03 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable
   
   -- Custom PickSlip
   ELSE
      SELECT @cPackData1 = LA.Lottable03
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.QTY > 0
         AND PD.Status = @cPickStatus
         AND PD.Status <> '4'
         AND PD.CaseID = ''
      GROUP BY LA.Lottable03
      ORDER BY CASE WHEN LA.Lottable03 = @cPrevPackData1 THEN 2 ELSE 1 END -- Last row is assign to variable

   SET @nRowCount = @@ROWCOUNT
   
   IF @nRowCount >= 1
   BEGIN
      SET @cDataCapture = '1' -- need to capture
      IF @cPackData1 <> @cPrevPackData1
         SET @cPackData1 = '' -- PackData changed, force key-in

		SET @cPackLabel1='Lottable03:'
      SET @cPackAttr1= ''
		SET @cPackAttr2 ='o'
		SET @cPackAttr3 ='o'

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1  
	END

   IF NOT EXISTS (SELECT 1 FROM sku (NOLOCK) 
               WHERE SKUGROUP='X708'
               AND storerkey=@cStorerKey
               AND sku=@cSKU)
   BEGIN
      SET @cDataCapture = '0' -- need to capture
   END

END

GO