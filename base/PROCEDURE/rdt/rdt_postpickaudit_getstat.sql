SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_PostPickAudit_GetStat                                 */
/*                                                                            */
/* Purpose: Get counted SKU, QTY                                              */
/*          Get pick list SKU, QTY                                            */
/*                                                                            */
/* Called from: 3                                                             */
/*    1. From PowerBuilder                                                    */
/*    2. From scheduler                                                       */
/*    3. From others stored procedures or triggers                            */
/*    4. From interface program. DX, DTS                                      */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2011-04-06 2.5  Ung        SOS208274                                       */
/*                            Add piece scanning                              */
/* 2012-12-26 2.6  James      SOS264934-Add new config to use packdetail      */
/*                            label no instead of dropid (james01)            */
/* 2013-05-02 2.7  Ung        SOS265337 Expand DropID 20 chars                */
/* 2014-07-15 2.8  Ung        SOS316336 Add variance check                    */
/* 31-07-2014 2.9  Ung        SOS316605 Add Prefer UOM and QTY                */
/* 10-03-2017 3.0  James      WMS1256 - Add scan pickdetail case id (james02) */
/* 05-07-2017 3.1  Ung        WMS-2331 Add PickDetail.ShipFlag (Reuse DropID) */
/* 13-09-2017 3.2  Ung        Performance tuning                              */
/* 05-10-2018 3.3  Ung        WMS-6510 Fix PQTY for PickSlipNo                */
/* 06-12-2018 3.4  Ung        WMS-6842 Add PreCartonization                   */
/* 16-11-2018 3.5  Ung        WMS-6932 Add pallet ID                          */
/* 03-01-2019 3.6  James      Filter ID with Qty > 0 (james03)                */
/* 03-29-2019 3.7  James      WMS-8002 Add TaskDetailKey (james04)            */
/* 22-04-2019 3.8  James      WMS-7983 Add ConvertQtySP (james05)             */
/* 10-02-2020 3.9  CheeMun    INC1012120-Revise IF-ELSE Statement             */
/* 07-02-2022 4.0 YeeKung     WMS-21562 customize refno to support            */
/*                            trackingno  (yeekung08)                         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PostPickAudit_GetStat] (
   @nMobile     INT,
   @nFunc       INT,
   @cRefNo      NVARCHAR( 20),
   @cPickSlipNo NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cID         NVARCHAR( 18),
   @cTaskDetailKey NVARCHAR( 10),
   @cStorer     NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUOM        NVARCHAR( 10),
   @nCSKU       INT = NULL OUTPUT,
   @nCQTY       INT = NULL OUTPUT,
   @nPSKU       INT = NULL OUTPUT,
   @nPQTY       INT = NULL OUTPUT,
   @nVariance   INT = NULL OUTPUT
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @cSQL             NVARCHAR(1000),
      @cSQLParam        NVARCHAR(1000)

   DECLARE
      @nPQTY_Total      INT,
      @nCQTY_Total      INT,
      @cConvertQTYSP       NVARCHAR( 20),
      @cPreCartonization   NVARCHAR( 1)

   DECLARE
      @nP_QTY           INT,
      @nC_QTY           INT,
      @cP_SKU           NVARCHAR( 20),
      @cC_SKU           NVARCHAR( 20)

   DECLARE  @cExtendedRefNoSP NVARCHAR(20),
            @cLangCode        NVARCHAR(20),
            @nStep            INT,
            @nErrNo           INT,
            @cErrMsg          NVARCHAR(MAX),
            @cSKU             NVARCHAR(20),
            @nQTY_PPA         INT,
            @nQTY_CHK         INT,
            @nRowRef          INT

   SELECT @cLangCode=lang_code,
          @nStep     = step
   FROM RDT.RDTMOBREC (NOLOCK)
   WHERE mobile=@nMobile

   IF @nVariance IS NOT NULL
   BEGIN
      DECLARE @tP TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
      DECLARE @tC TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
   END

   -- Get storer configure
   SET @cPreCartonization = rdt.RDTGetConfig( @nFunc, 'PreCartonization', @cStorer)
   SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer)
   IF @cConvertQTYSP = '0'
      SET @cConvertQTYSP = ''
   SET @cExtendedRefNoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedRefNoSP', @cStorer)
   IF @cExtendedRefNoSP = '0'
      SET @cExtendedRefNoSP = ''

-- Note: do not merge the count distinct SKU and sum QTY, into one SQL statements
--       if merged it will create temp table for distinct count
    
               -- (ChewKP01)
   IF @cExtendedRefNoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedRefNoSP AND type = 'P')--yeekung08
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedRefNoSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey,  @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,@cType, ' + 
         ' @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
         '@nMobile        INT, ' +                      
         '@nFunc          INT, ' +                      
         '@cLangCode      NVARCHAR( 3),  ' +            
         '@nStep          INT,           ' +            
         '@cStorer        NVARCHAR( 15), ' +            
         '@cFacility      NVARCHAR( 5),  ' +            
         '@cRefNo         NVARCHAR( 20), ' +            
         '@cOrderKey      NVARCHAR( 10), ' +            
         '@cDropID        NVARCHAR( 20), ' +            
         '@cLoadKey       NVARCHAR( 10), ' +            
         '@cPickSlipNo    NVARCHAR( 10), ' +            
         '@cID            NVARCHAR( 18),       '+       
         '@cTaskDetailKey NVARCHAR( 10),       '+       
         '@cSKU           NVARCHAR( 20),       ' +      
         '@cType          NVARCHAR( 20),       '+       
         '@nCSKU          INT  OUTPUT ,  '+             
         '@nCQTY          INT  OUTPUT ,  '+             
         '@nPSKU          INT OUTPUT,          '+       
         '@nPQTY          INT OUTPUT,          '+       
         '@nVariance      INT OUTPUT,   '+              
         '@nQTY_PPA       INT OUTPUT,          '+       
         '@nQTY_CHK       INT OUTPUT,          '+   
         '@nRowRef        INT OUTPUT,          '+ 
         '@nErrNo         INT           OUTPUT,'+       
         '@cErrMsg        NVARCHAR( 20) OUTPUT '        

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,'GetStat',
         @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT


         IF @nErrNo <> 0
         BEGIN
            GOTO QUIT
         END
             
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedRefNoSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey,  @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,@cType, ' + 
         ' @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
         '@nMobile        INT, ' +                      
         '@nFunc          INT, ' +                      
         '@cLangCode      NVARCHAR( 3),  ' +            
         '@nStep          INT,           ' +            
         '@cStorer        NVARCHAR( 15), ' +            
         '@cFacility      NVARCHAR( 5),  ' +            
         '@cRefNo         NVARCHAR( 20), ' +            
         '@cOrderKey      NVARCHAR( 10), ' +            
         '@cDropID        NVARCHAR( 20), ' +            
         '@cLoadKey       NVARCHAR( 10), ' +            
         '@cPickSlipNo    NVARCHAR( 10), ' +            
         '@cID            NVARCHAR( 18),       '+       
         '@cTaskDetailKey NVARCHAR( 10),       '+       
         '@cSKU           NVARCHAR( 20),       ' +      
         '@cType          NVARCHAR( 20),       '+       
         '@nCSKU          INT  OUTPUT ,  '+             
         '@nCQTY          INT  OUTPUT ,  '+             
         '@nPSKU          INT OUTPUT,          '+       
         '@nPQTY          INT OUTPUT,          '+       
         '@nVariance      INT OUTPUT,   '+              
         '@nQTY_PPA       INT OUTPUT,          '+       
         '@nQTY_CHK       INT OUTPUT,          '+   
         '@nRowRef        INT OUTPUT,          '+       
         '@nErrNo         INT           OUTPUT,'+       
         '@cErrMsg        NVARCHAR( 20) OUTPUT '        
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,'INSERT',
         @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO QUIT
         END

         IF @nVariance IS NOT NULL
         BEGIN
            IF @nCQTY<>''
            BEGIN
               INSERT INTO @tC (StorerKey, SKU, QTY)
               SELECT @cStorer,@cSKU,@nCQTY
            END
         END
      END
   END
   ELSE
   BEGIN
      -- RefNo
      IF @cRefNo <> '' AND @cRefNo IS NOT NULL
      BEGIN

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND RefKey = @cRefNo
            GROUP BY StorerKey, SKU
      END

      -- Pick Slip No
      ELSE IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL     --INC1012120
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

         -- Cross dock pick slip
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo
               GROUP BY PD.StorerKey, PD.SKU
         END

         -- Discrete pick slip
         ELSE IF @cOrderKey <> ''
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT OD.SKU)
               FROM dbo.OrderDetail OD WITH (NOLOCK)
               WHERE OD.OrderKey = @cOrderKey

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cOrderKey
                  --AND PD.Status >= '5'

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cOrderKey
               GROUP BY PD.StorerKey, PD.SKU
         END

         -- Conso pick slip
         ELSE IF @cExternOrderKey <> ''
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT OD.SKU)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               WHERE O.LoadKey = @cExternOrderKey

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.Orders O WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.LoadKey = @cExternOrderKey
                  --AND PD.Status >= '5'

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.Orders O WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.LoadKey = @cExternOrderKey
               GROUP BY PD.StorerKey, PD.SKU
         END

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND PickSlipNo = @cPickSlipNo

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND PickSlipNo = @cPickSlipNo

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND PickSlipNo = @cPickSlipNo
            GROUP BY StorerKey, SKU
      END

      -- LoadKey
      ELSE IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL       --INC1012120
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               --AND PD.Status >= '5'

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               --AND PD.Status >= '5'

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND LoadKey = @cLoadKey
            GROUP BY StorerKey, SKU
      END

      -- OrderKey
      ELSE IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL         --INC1012120
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND OrderKey = @cOrderKey

         IF @nCQTY IS NOT NULL
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND OrderKey = @cOrderKey

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND OrderKey = @cOrderKey
            GROUP BY StorerKey, SKU
      END

      -- DropID
      ELSE IF @cDropID <> '' AND @cDropID IS NOT NULL            --INC1012120
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorer) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.DropID = @cDropID

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.DropID = @cDropID

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.DropID = @cDropID
               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorer) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.LabelNo = @cDropID

            IF @nPQTY IS NOT NULL
            BEGIN
               -- If convert qty sp setup then no need to get the base qty at this point
               IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer) <> ''
                  AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
               BEGIN
                  SET @nPQTY_Total = 0
                  DECLARE @curPQTY_Total CURSOR
                  SET @curPQTY_Total = CURSOR FOR
                  SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
                  WHERE PD.StorerKey = @cStorer
                     AND PD.LabelNo = @cDropID
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
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cP_SKU, @nP_QTY OUTPUT

                     SET @nPQTY_Total = @nPQTY_Total + @nP_QTY
                     FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
                  END
                  CLOSE @curPQTY_Total
                  DEALLOCATE @curPQTY_Total

                  SET @nPQTY = @nPQTY_Total
               END
               ELSE
                  SELECT @nPQTY = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
                  WHERE PD.StorerKey = @cStorer
                     AND PD.LabelNo = @cDropID
            END

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.LabelNo = @cDropID
               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorer) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorer
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorer
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorer
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorer
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'

            IF @nPQTY IS NOT NULL
            BEGIN
               -- If convert qty sp setup then no need to get the base qty at this point
               IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer) <> ''
                  AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
               BEGIN
                  SET @nPQTY_Total = 0
                  SET @curPQTY_Total = CURSOR FOR
                  SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorer
                     AND PD.DropID = @cDropID
                     AND PD.ShipFlag <> 'Y'
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
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cP_SKU, @nP_QTY OUTPUT

                     SET @nPQTY_Total = @nPQTY_Total + @nP_QTY
                     FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
                  END
                  CLOSE @curPQTY_Total
                  DEALLOCATE @curPQTY_Total

                  SET @nPQTY = @nPQTY_Total
               END
               ELSE
                  SELECT @nPQTY = SUM( PD.QTY)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorer
                     AND PD.DropID = @cDropID
                     AND PD.ShipFlag <> 'Y'
            END

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorer
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
               GROUP BY PD.StorerKey, PD.SKU
         END

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND DropID = @cDropID

         IF @nCQTY IS NOT NULL
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer) <> ''
               AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
            BEGIN
               SET @nCQTY_Total = 0
               DECLARE @curCQTY_Total CURSOR
               SET @curCQTY_Total = CURSOR FOR
               SELECT SKU, ISNULL( SUM( CQTY), 0)
               FROM rdt.rdtPPA WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND DropID = @cDropID
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
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cC_SKU, @nC_QTY OUTPUT

                  SET @nCQTY_Total = @nCQTY_Total + @nC_QTY
                  FETCH NEXT FROM @curCQTY_Total INTO @cC_SKU, @nC_QTY
               END
               CLOSE @curCQTY_Total
               DEALLOCATE @curCQTY_Total

               SET @nCQTY = @nCQTY_Total
            END
            ELSE
               SELECT
                  @nCQTY = SUM( CQTY)
               FROM rdt.rdtPPA WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND DropID = @cDropID
         END

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND DropID = @cDropID
            GROUP BY StorerKey, SKU
      END

      -- ID
      ELSE IF @cID <> '' AND @cID IS NOT NULL             --INC1012120
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT LLI.SKU)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorer
               AND LLI.ID = @cID
               AND LLI.QTY > 0

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( LLI.QTY)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorer
               AND LLI.ID = @cID
               AND LLI.QTY > 0

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT LLI.StorerKey, LLI.SKU, ISNULL( SUM( LLI.QTY), 0)
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cID
               AND LLI.StorerKey = @cStorer
               AND LLI.QTY > 0
            GROUP BY LLI.StorerKey, LLI.SKU

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND ID = @cID

         IF @nCQTY IS NOT NULL
         BEGIN
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND ID = @cID
         END

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND ID = @cID
            GROUP BY StorerKey, SKU
      END

      -- TaskDetailKey
      ELSE IF @cTaskDetailKey <> '' AND @cTaskDetailKey IS NOT NULL       --INC1012120
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT SKU)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( QTY)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( QTY), 0)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey
            GROUP BY StorerKey, SKU

         IF @nCSKU IS NOT NULL
            SELECT
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND TaskDetailKey = @cTaskDetailKey

         IF @nCQTY IS NOT NULL
         BEGIN
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND TaskDetailKey = @cTaskDetailKey
         END

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND TaskDetailKey = @cTaskDetailKey
            GROUP BY StorerKey, SKU
      END

      -- SUM() might return NULL when no record
      SET @nCQTY = IsNULL( @nCQTY, 0)
      SET @nPQTY = IsNULL( @nPQTY, 0)

      -- Get variance
      IF @nVariance IS NOT NULL
      BEGIN
         IF EXISTS( SELECT TOP 1 1
            FROM @tP P
               FULL OUTER JOIN @tC C ON (P.SKU = C.SKU)
            WHERE P.SKU IS NULL
               OR C.SKU IS NULL
               OR P.QTY <> C.QTY)
            SET @nVariance = 1
         ELSE
            SET @nVariance = 0
      END
   END

QUIT:
END

GO