SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt.rdt_855ExtInfo06                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2019-04-17 1.0  James    WMS-7983 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_855ExtInfo06]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @cSQL             NVARCHAR(1000),   
   @cSQLParam        NVARCHAR(1000) 

   DECLARE @nCount            INT
   DECLARE @nRowCount         INT

   DECLARE @cErrMsg01         NVARCHAR( 20)
   DECLARE @cErrMsg02         NVARCHAR( 20)
   DECLARE @cErrMsg03         NVARCHAR( 20)
   DECLARE @cErrMsg04         NVARCHAR( 20)
   DECLARE @cErrMsg05         NVARCHAR( 20)
   
   DECLARE @cPickSlipNo     NVARCHAR( 10)
   DECLARE @cLoadKey        NVARCHAR( 10)
   DECLARE @cOrderKey       NVARCHAR( 10)
   DECLARE @cDropID         NVARCHAR( 20)
   DECLARE @cSKU            NVARCHAR( 20)
   DECLARE @cPPACartonIDByPickDetailCaseID  NVARCHAR( 1)
   DECLARE @cPPACartonIDByPackDetailLabelNo NVARCHAR( 1)
   DECLARE @cPPACartonIDByPackDetailDropID  NVARCHAR( 1)
   DECLARE @nDropIDCnt      INT
   DECLARE @nTTL_DropIDCnt  INT
   DECLARE @nPSKU           INT
   DECLARE @nPQTY           INT
   DECLARE @nCSKU           INT
   DECLARE @nCQTY           INT
   DECLARE @nPQTY_Total     INT
   DECLARE @nCQTY_Total     INT
   DECLARE @nP_QTY          INT
   DECLARE @nC_QTY          INT
   DECLARE @cP_SKU          NVARCHAR( 20)
   DECLARE @cC_SKU          NVARCHAR( 20) 
   DECLARE @fCaseCnt        FLOAT
   DECLARE @cConvertQTYSP   NVARCHAR( 20)
   DECLARE @curPQTY_Total   CURSOR

   -- Variable mapping
   SELECT @cDropID = Value FROM @tExtInfo WHERE Variable = '@cDropID'
   SELECT @cLoadKey = Value FROM @tExtInfo WHERE Variable = '@cLoadKey'

   IF @nFunc = 855 -- PPA by DropID
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey)  
            SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey)  
            SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)  

            SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey)  
            IF @cConvertQTYSP = '0'  
               SET @cConvertQTYSP = ''  

            -- Validate drop ID status
            IF @cPPACartonIDByPackDetailDropID = '1'
            BEGIN
               SELECT TOP 1 @cPickSlipNo = PH.PickSlipNo, @cSKU = PD.SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.DropID = @cDropID
               AND   PH.StorerKey = @cStorerKey
               ORDER BY 1

               SELECT @cLoadKey = ExternOrderKey
               FROM dbo.PickHeader WITH (NOLOCK) 
               WHERE PickHeaderKey = @cPickSlipNo

               SELECT @nTTL_DropIDCnt = COUNT( DISTINCT PD.DropID)
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   ISNULL( PD.DropID, '') <> ''

               SELECT @nDropIDCnt = COUNT( DISTINCT DropID)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.DropID
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   ISNULL( PD.DropID, '') <> '')

               SELECT @nCSKU = COUNT( DISTINCT SKU),
                      @nCQTY = ISNULL( SUM( CQTY), 0)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.DropID
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   PD.DropID = @cDropID)

               SELECT @nPSKU = COUNT( DISTINCT PD.SKU),
                      @nPQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   PD.DropID = @cDropID
            END
            ELSE
            IF @cPPACartonIDByPackDetailLabelNo = '1'
            BEGIN
               SELECT TOP 1 @cPickSlipNo = PH.PickSlipNo, @cSKU = PD.SKU
               FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.LabelNo = @cDropID
               AND   PH.StorerKey = @cStorerKey
               ORDER BY 1

               SELECT @cLoadKey = ExternOrderKey
               FROM dbo.PickHeader WITH (NOLOCK) 
               WHERE PickHeaderKey = @cPickSlipNo

               SELECT @nTTL_DropIDCnt = COUNT( DISTINCT PD.LabelNo)
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   ISNULL( PD.LabelNo, '') <> ''

               SELECT @nDropIDCnt = COUNT( DISTINCT DropID)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.LabelNo
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   ISNULL( PD.LabelNo, '') <> '')

               SELECT @nCSKU = COUNT( DISTINCT SKU),
                      @nCQTY = ISNULL( SUM( CQTY), 0)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.LabelNo
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   PD.LabelNo = @cDropID)

               SELECT @nPSKU = COUNT( DISTINCT PD.SKU),
                      @nPQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
               WHERE PH.ExternOrderKey = @cLoadKey
               AND   PD.LabelNo = @cDropID
            END
            ELSE
            IF @cPPACartonIDByPickDetailCaseID = '1'
            BEGIN
               SELECT TOP 1 @cOrderKey = OrderKey, @cSKU = SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE CaseID = @cDropID
               AND   StorerKey = @cStorerKey
               AND   ShipFlag <> 'Y'
               ORDER BY 1

               SELECT @cLoadKey = LoadKey
               FROM dbo.ORDERS WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey

               SELECT @nTTL_DropIDCnt = COUNT( DISTINCT PD.CaseID)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   ISNULL( PD.CaseID, '') <> ''

               SELECT @nDropIDCnt = COUNT( DISTINCT DropID)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.CaseID
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   ISNULL( PD.CaseID, '') <> '')

               SELECT @nCSKU = COUNT( DISTINCT SKU),
                      @nCQTY = ISNULL( SUM( CQTY), 0)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.CaseID
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   PD.CaseID = @cDropID)

               SELECT @nPSKU = COUNT( DISTINCT PD.SKU),
                      @nPQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LoadPlanDetail AS LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   PD.CaseID = @cDropID
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cOrderKey = OrderKey, @cSKU = SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE DropID = @cDropID
               AND   StorerKey = @cStorerKey
               AND   ShipFlag <> 'Y'
               ORDER BY 1

               SELECT @cLoadKey = LoadKey
               FROM dbo.ORDERS WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey

               SELECT @nTTL_DropIDCnt = COUNT( DISTINCT PD.DropID)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   ISNULL( PD.DropID, '') <> ''

               SELECT @nDropIDCnt = COUNT( DISTINCT DropID) 
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.DropID
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                  WHERE LPD.LoadKey = @cLoadKey
                  AND   ISNULL( PD.DropID, '') <> '')

               SELECT @nCSKU = COUNT( DISTINCT SKU)
               FROM RDT.RDTPPA PPA WITH (NOLOCK)
               WHERE DropID IN (
                  SELECT DISTINCT PD.DropID
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                  WHERE LPD.LoadKey = @cLoadKey
                  AND   PD.DropID = @cDropID)

               IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey) <> '' 
                  AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
               BEGIN
                  SET @nCQTY_Total = 0
                  DECLARE @curCQTY_Total CURSOR
                  SET @curCQTY_Total = CURSOR FOR 
                  SELECT SKU, ISNULL( SUM( CQTY), 0) 
                  FROM RDT.RDTPPA PPA WITH (NOLOCK)
                  WHERE DropID IN (
                     SELECT DISTINCT PD.DropID
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                     WHERE LPD.LoadKey = @cLoadKey
                     AND   PD.DropID = @cDropID)
                  GROUP BY SKU
                  OPEN @curCQTY_Total
                  FETCH NEXT FROM @curCQTY_Total INTO @cC_SKU, @nC_QTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'  
                     SET @cSQLParam =  
                        '@cType   NVARCHAR( 10), ' +    
                        '@cStorer NVARCHAR( 15), ' +    
                        '@cSKU    NVARCHAR( 20), ' +    
                        '@nQTY    INT OUTPUT'  
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorerKey, @cC_SKU, @nC_QTY OUTPUT  
   
                     SET @nCQTY_Total = @nCQTY_Total + @nC_QTY
                     FETCH NEXT FROM @curCQTY_Total INTO @cC_SKU, @nC_QTY
                  END
                  CLOSE @curCQTY_Total
                  DEALLOCATE @curCQTY_Total
         
                  SET @nCQTY = @nCQTY_Total
               END
               ELSE
                  SELECT @nCQTY = ISNULL( SUM( CQTY), 0)
                  FROM RDT.RDTPPA PPA WITH (NOLOCK)
                  WHERE DropID IN (
                     SELECT DISTINCT PD.DropID
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                     WHERE LPD.LoadKey = @cLoadKey
                     AND   PD.DropID = @cDropID)

               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               JOIN dbo.LoadPlanDetail AS LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cLoadKey
               AND   PD.DropID = @cDropID

               IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey) <> '' 
                  AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
               BEGIN
                  SET @nPQTY_Total = 0
                  SET @curPQTY_Total = CURSOR FOR 
                  SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0) 
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LoadPlanDetail AS LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                  WHERE LPD.LoadKey = @cLoadKey
                  AND   PD.DropID = @cDropID
                  GROUP BY PD.SKU
                  OPEN @curPQTY_Total
                  FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'  
                     SET @cSQLParam =  
                        '@cType   NVARCHAR( 10), ' +    
                        '@cStorer NVARCHAR( 15), ' +    
                        '@cSKU    NVARCHAR( 20), ' +    
                        '@nQTY    INT OUTPUT'  
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorerKey, @cP_SKU, @nP_QTY OUTPUT  
   
                     SET @nPQTY_Total = @nPQTY_Total + @nP_QTY
                     FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
                  END
                  CLOSE @curPQTY_Total
                  DEALLOCATE @curPQTY_Total
            
                  SET @nPQTY = @nPQTY_Total
               END
               ELSE
                  SELECT @nPQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LoadPlanDetail AS LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                  WHERE LPD.LoadKey = @cLoadKey
                  AND   PD.DropID = @cDropID
            END

            SET @cErrMsg01 = 'LOADKEY: ' + @cLoadKey
            SET @cErrMsg02 = ''
            SET @cErrMsg03 = 'CARTON CKD: ' + RTRIM( CAST( @nDropIDCnt AS NVARCHAR( 3))) + '/' + RTRIM( CAST( @nTTL_DropIDCnt AS NVARCHAR( 3)))
            SET @cErrMsg04 = 'SKU CKD: ' + RTRIM( CAST( @nCSKU AS NVARCHAR( 2))) + '/' + RTRIM( CAST( @nPSKU AS NVARCHAR( 2)))
            SET @cErrMsg05 = 'QTY CKD: ' + RTRIM( CAST( @nCQTY AS NVARCHAR( 5))) + '/' + RTRIM( CAST( @nPQTY AS NVARCHAR( 5)))
            --insert into traceinfo (tracename, timein, col1, col2, col3, col4) values
            --('855', getdate(), @nCSKU, @nPSKU, @nCQTY, @nPQTY)

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05

            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
      END
   END
   
Quit:
   
END

GO