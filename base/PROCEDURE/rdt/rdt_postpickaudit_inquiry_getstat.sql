SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PostPickAudit_Inquiry_GetStat                   */  
/*                                                                      */  
/* Purpose: Info of Pick vs PPA                                         */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2011-05-26 1.0  Ung        Created                                   */  
/* 22-12-2015 1.1  Leong      SOS359525 - Revise variable size.         */  
/* 04-11-2016 1.2  ChewKP     WMS-611 Add RDT Config                    */  
/*                            "PPACartonIDByPickDetailCaseID"           */  
/*                            "DisplayStyleColorSize"                   */  
/*                            Support User Preferred UOM (ChewKP01)     */  
/* 05-12-2018 1.3  James      WMS7191 - Add support filter by           */  
/*                            packdetail.labelno (james01)              */  
/* 24-09-2018 1.4  James      WMS7751-Remove OD.loadkey (james02)       */
/* 26-11-2019 1.5  LZG        INC0948516-Standardized with parent (ZG01)*/
/* 22-01-2020 1.6  CheeMun    INC1012120-Revise IF-ELSE Statement       */ 																			
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PostPickAudit_Inquiry_GetStat] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cRefNo       NVARCHAR( 10),  
   @cPickSlipNo  NVARCHAR( 10),  
   @cLoadKey     NVARCHAR( 10),  
   @cOrderKey    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20), -- SOS359525  
   @cSKU         NVARCHAR( 20),  
   @cStorer      NVARCHAR( 15),  
   @cUOM         NVARCHAR( 10),  
   @cCurrentSKU  NVARCHAR( 20),  
   @cPPACartonIDByPackDetailDropID NVARCHAR( 1),  
   @cTally       NVARCHAR( 1)  OUTPUT,  
   @nTotSKU_Pick INT       OUTPUT,  
   @nTotQTY_Pick INT       OUTPUT,  
   @nTotSKU_PPA  INT       OUTPUT,  
   @nTotQTY_PPA  INT       OUTPUT,  
   @nQTY_Pick    INT       OUTPUT,  
   @nQTY_PPA     INT       OUTPUT,  
   @cNextSKU     NVARCHAR( 20) OUTPUT,  
   @cSKUDescr    NVARCHAR( 60) OUTPUT,  
   @cSKUInfo     NVARCHAR( 20) OUTPUT,  
   @nRec         INT       OUTPUT,  
   @nTotRec      INT       OUTPUT  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Create temp table  
CREATE TABLE #Pick (SKU NVARCHAR( 20), QTY INT)  
CREATE TABLE #PPA  (SKU NVARCHAR( 20), QTY INT)  
  
DECLARE @cPPACartonIDByPickDetailCaseID NVARCHAR(1)   
        ,@cDispStyleColorSize           NVARCHAR(1)   
        ,@cStyle                        NVARCHAR( 20)   
        ,@cColor                        NVARCHAR( 10)   
        ,@cSize                         NVARCHAR( 10)   
        ,@cPPACartonIDByPackDetailLabelNo NVARCHAR( 1)  
          
          
--SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorer)  -- (ChewKP01)   
SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( 0, 'PPACartonIDByPickDetailCaseID', @cStorer)  -- ZG01
SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorer)  -- (james01)   
SET @cDispStyleColorSize = rdt.rdtGetConfig( @nFunc, 'DispStyleColorSize', @cStorer)  -- (ChewKP01)   
SET @cSKUInfo = ''  
  
-- RefNo  
IF @cRefNo <> '' AND @cRefNo IS NOT NULL  
BEGIN  
   INSERT INTO #Pick  
   SELECT PD.SKU, SUM( PD.QTY /  
      CASE @cUOM  
         WHEN '2' THEN CASE PACK.CASECNT    WHEN 0 THEN 1 ELSE PACK.CASECNT    END  
         WHEN '3' THEN CASE PACK.InnerPack  WHEN 0 THEN 1 ELSE PACK.InnerPack  END  
         WHEN '6' THEN CASE PACK.Qty        WHEN 0 THEN 1 ELSE PACK.Qty        END  
         WHEN '1' THEN CASE PACK.Pallet     WHEN 0 THEN 1 ELSE PACK.Pallet     END  
         WHEN '4' THEN CASE PACK.otherunit1 WHEN 0 THEN 1 ELSE PACK.otherunit1 END  
         WHEN '5' THEN CASE PACK.otherunit2 WHEN 0 THEN 1 ELSE PACK.otherunit2 END  
         ELSE 1  
      END)  
   FROM dbo.LoadPlan AS LP WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.LoadKey = LP.LoadKey
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = O.OrderKey
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey
   WHERE LP.UserDefine10 = @cRefNo  
      AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
   GROUP BY PD.SKU  
      --AND PD.Status >= '5'  
  
   INSERT INTO #PPA  
   SELECT SKU, SUM( CQTY)  
   FROM rdt.rdtPPA WITH (NOLOCK)  
   WHERE StorerKey = @cStorer  
      AND RefKey = @cRefNo  
      AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
   GROUP BY SKU  
  
END  
  
-- Pick Slip No  
ELSE IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL    --INC1012120
BEGIN  
   -- Get pickheader info  
   DECLARE @cExternOrderKey NVARCHAR( 20)  
   DECLARE @cZone           NVARCHAR( 18)  
   SELECT TOP 1  
      @cExternOrderKey = ExternOrderkey,  
      @cOrderKey = OrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  
  
   IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'  
   BEGIN  
      INSERT INTO #Pick  
      SELECT PD.SKU, SUM( PD.QTY)  
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey  
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON PD.PackKey = Pack.PackKey  
      WHERE RKL.PickSlipNo = @cPickSlipNo  
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
      GROUP BY PD.SKU  
   END  
   ELSE IF(ISNULL(@cExternOrderKey, '') <> '')  
   BEGIN    
      INSERT INTO #Pick    
      SELECT PD.SKU, SUM( PD.QTY)    
      FROM dbo.OrderDetail OD WITH (NOLOCK)    
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey    
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber    
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey    
      WHERE O.LoadKey = @cExternOrderKey    
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END    
      GROUP BY PD.SKU    
   END   
   ELSE IF(ISNULL(@cOrderKey, '') <> '')  
   BEGIN    
      INSERT INTO #Pick    
      SELECT PD.SKU, SUM( PD.QTY)    
      FROM dbo.OrderDetail OD WITH (NOLOCK)    
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON OD.OrderKey = O.OrderKey    
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber    
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey    
      WHERE OD.OrderKey = @cOrderKey 
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END    
      GROUP BY PD.SKU
   END  
  
   INSERT INTO #PPA  
   SELECT SKU, SUM( CQTY)  
   FROM rdt.rdtPPA WITH (NOLOCK)  
   WHERE StorerKey = @cStorer  
      AND PickSlipNo = @cPickSlipNo  
      AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
   GROUP BY SKU  
END  
  
-- LoadKey  
ELSE IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL    	--INC1012120 
BEGIN  
   INSERT INTO #Pick  
   SELECT PD.SKU, SUM( PD.QTY)  
   FROM dbo.LoadPlan AS LP WITH (NOLOCK)  
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.LoadKey = LP.LoadKey  
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber  
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey  
   WHERE LP.LoadKey = @cLoadKey  
      AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
   GROUP BY PD.SKU  
  
   INSERT INTO #PPA  
   SELECT SKU, SUM( CQTY)  
   FROM rdt.rdtPPA WITH (NOLOCK)  
   WHERE StorerKey = @cStorer  
      AND LoadKey = @cLoadKey  
      AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
   GROUP BY SKU  
END  
  
-- OrderKey  
ELSE IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL    --INC1012120
BEGIN  
   INSERT INTO #Pick  
   SELECT PD.SKU, SUM( PD.QTY)  
   FROM dbo.PickDetail PD WITH (NOLOCK)  
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = PD.PackKey  
   WHERE PD.OrderKey = @cOrderKey  
      AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
   GROUP BY PD.SKU  
  
   INSERT INTO #PPA  
   SELECT SKU, SUM( CQTY)  
   FROM rdt.rdtPPA WITH (NOLOCK)  
   WHERE StorerKey = @cStorer  
      AND OrderKey = @cOrderKey  
      AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
   GROUP BY SKU  
END  
  
-- DropID  
ELSE IF @cDropID <> '' AND @cDropID IS NOT NULL    		--INC1012120
BEGIN  
   IF @cPPACartonIDByPackDetailDropID = '1'  
   BEGIN  
      INSERT INTO #Pick  
      SELECT PD.SKU, SUM( PD.QTY )   
      FROM dbo.PackDetail PD WITH (NOLOCK)  
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU  
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = SKU.PackKey  
      WHERE PD.StorerKey = @cStorer  
         AND PD.DropID = @cDropID  
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
      GROUP BY PD.SKU  
   END  
   ELSE IF @cPPACartonIDByPackDetailLabelNo = '1' --INC1012120 
   BEGIN  
      INSERT INTO #Pick  
      SELECT PD.SKU, SUM( PD.QTY )  
      FROM dbo.PackHeader PH WITH (NOLOCK)  
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)  
      WHERE PD.LabelNo = @cDropID  
         AND PH.StorerKey = @cStorer  
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
      GROUP BY PD.SKU  
   END  
   ELSE IF @cPPACartonIDByPickDetailCaseID = '1' -- (ChewKP01)   
   BEGIN  
      INSERT INTO #Pick  
      SELECT PD.SKU, SUM( PD.QTY)  
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU  
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = SKU.PackKey  
      WHERE PD.StorerKey = @cStorer  
         AND PD.CaseID = @cDropID  
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
      GROUP BY PD.SKU  
   END  
   ELSE  
   BEGIN  
      INSERT INTO #Pick  
      SELECT PD.SKU, SUM( PD.QTY )   
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = PD.PackKey  
      WHERE PD.StorerKey = @cStorer  
         AND PD.DropID = @cDropID  
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END  
      GROUP BY PD.SKU  
   END  
  
   INSERT INTO #PPA  
   SELECT SKU, SUM( CQTY)  
   FROM rdt.rdtPPA WITH (NOLOCK)  
   WHERE StorerKey = @cStorer  
      AND DropID = @cDropID  
      AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
   GROUP BY SKU  
END  
  
-- Get total SKU, QTY for pick and PPA  
SELECT @nTotSKU_Pick = COUNT( 1), @nTotQTY_Pick = ISNULL( SUM( QTY), 0) FROM #Pick  
SELECT @nTotSKU_PPA  = COUNT( 1), @nTotQTY_PPA  = ISNULL( SUM( QTY), 0) FROM #PPA  
  
  
  
-- Check if pick and PPA tally  
SET @cTally = 'N'  
IF NOT EXISTS( SELECT 1  
   FROM #Pick Pick  
      FULL OUTER JOIN #PPA PPA ON (Pick.SKU = PPA.SKU)  
   WHERE Pick.SKU IS NULL  
      OR PPA.SKU IS NULL  
      OR Pick.QTY <> PPA.QTY)  
BEGIN  
   SET @cTally = 'Y'  
   GOTO Quit  
END  
  
DECLARE @curSKU NVARCHAR( 20)  
DECLARE @curDiff CURSOR  
SET @cNextSKU = ''  
SET @nRec = 0  
SET @nTotRec = 0  
  
-- Get SKU and rec count  
SET @curDiff = CURSOR STATIC FORWARD_ONLY READ_ONLY FOR  -- STATIC is required for @@CURSOR_ROWS below  
   SELECT CASE WHEN Pick.SKU IS NOT NULL THEN Pick.SKU ELSE PPA.SKU END SKU  
   FROM #Pick Pick  
      FULL OUTER JOIN #PPA PPA ON (Pick.SKU = PPA.SKU)  
   WHERE Pick.SKU IS NULL  
      OR PPA.SKU IS NULL  
      OR Pick.QTY <> PPA.QTY  
   ORDER BY 1  
OPEN @curDiff  
FETCH NEXT FROM @curDiff INTO @curSKU  
WHILE @@FETCH_STATUS = 0  
BEGIN  
   SET @nRec = @nRec + 1  
   SET @cNextSKU = @curSKU  
   IF @cNextSKU > @cCurrentSKU  
      BREAK  
   FETCH NEXT FROM @curDiff INTO @curSKU  
END  
SET @nTotRec = @@CURSOR_ROWS  
  
CLOSE @curDiff  
DEALLOCATE @curDiff  
  
-- Calc SKU pick and PPA QTY  
SELECT @nQTY_Pick = ISNULL( SUM( QTY), 0) FROM #Pick WHERE SKU = @cNextSKU  
SELECT @nQTY_PPA  = ISNULL( SUM( QTY), 0) FROM #PPA  WHERE SKU = @cNextSKU  
  
-- Get SKU details  
  
IF ISNULL( @cDispStyleColorSize,'' )  <> ''   
BEGIN  
   SELECT  
      @cSKUDescr = SKU.DESCR,  
      @cStyle = SKU.Style ,  
      @cColor = SKU.Color ,  
      @cSize  = SKU.Size    
   FROM dbo.SKU SKU WITH (NOLOCK)  
   WHERE SKU.StorerKey = @cStorer  
      AND SKU.SKU = @cNextSKU  
        
     
   IF ISNULL(@cDispStyleColorSize,'' )  = 'T'  
      SET @cSKUInfo = @cStyle  
   ELSE IF ISNULL(@cDispStyleColorSize,'' )  = 'C'  
      SET @cSKUInfo = @cColor  
   ELSE IF ISNULL(@cDispStyleColorSize,'' )  = 'S'  
      SET @cSKUInfo = @cSize  
   ELSE  
      SET @cSKUInfo = ''   
END  
  
Quit:  
   IF OBJECT_ID( 'tempdb..#Pick') IS NOT NULL DROP TABLE #Pick  
   IF OBJECT_ID( 'tempdb..#PPA' ) IS NOT NULL DROP TABLE #PPA  

GO