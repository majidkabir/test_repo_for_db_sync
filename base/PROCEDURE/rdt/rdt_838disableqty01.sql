SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DisableQTY01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-02-18 1.0  James       WMS-12052 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838DisableQTY01] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @nCartonNo           INT,
   @cLabelNo            NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @nQTY                INT,
   @cUCCNo              NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cSerialNo           NVARCHAR( 30),
   @nSerialQTY          INT,
   @cOption             NVARCHAR( 1),
   @cPackDtlRefNo       NVARCHAR( 20), 
   @cPackDtlRefNo2      NVARCHAR( 20), 
   @cPackDtlUPC         NVARCHAR( 30), 
   @cPackDtlDropID      NVARCHAR( 20), 
   @cPackData1          NVARCHAR( 30), 
   @cPackData2          NVARCHAR( 30), 
   @cPackData3          NVARCHAR( 30),
   @tVarDisableQTYField VARIABLETABLE  READONLY,
   @cDisableQTYField    NVARCHAR( 1)   OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 10)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cPSType     NVARCHAR( 10)
   DECLARE @cCompany    NVARCHAR( 45)

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 2 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cZone = Zone, 
                   @cLoadKey = ExternOrderKey,
                   @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)     
            WHERE PickHeaderKey = @cPickSlipNo

            -- Get PickSlip type
            IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
               SET @cPSType = 'XD'
            ELSE IF @cOrderKey = ''
               SET @cPSType = 'CONSO'
            ELSE IF @cOrderKey <> ''
               SET @cPSType = 'DISCRETE'
            ELSE
               SET @cPSType = 'CUSTOM'

            SET @cDisableQTYField = '1'

            -- Xdock picklist
            IF @cPSType = 'XD'
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey) 
                  WHERE RKL.PickSlipNo = @cPickSlipNo 
                  AND   PD.StorerKey = @cStorerKey 
                  AND   PD.Status <> '4'
                  AND   O.C_Company = 'WHS')
                  SET @cDisableQTYField = 'O'
            END
            -- Discrete PickSlip
            ELSE IF @cPSType = 'DISCRETE' 
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)  
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                  WHERE PD.OrderKey = @cOrderKey 
                  AND   PD.StorerKey = @cStorerKey 
                  AND   PD.Status <> '4'
                  AND   O.C_Company = 'WHS')
                  SET @cDisableQTYField = 'O'
            END
            -- CONSO PickSlip
            ELSE IF @cPSType = 'CONSO' 
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey) 
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey 
                  AND   PD.StorerKey = @cStorerKey 
                  AND   PD.Status <> '4'
                  AND   O.C_Company = 'WHS')
                  SET @cDisableQTYField = 'O'
            END
            -- Custom PickSlip
            ELSE
            BEGIN
               IF EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
                  WHERE PD.PickSlipNo = @cPickSlipNo  
                  AND   PD.StorerKey = @cStorerKey 
                  AND   PD.Status <> '4'   
                  AND   O.C_Company = 'WHS')
                  SET @cDisableQTYField = 'O'
            END
         END
      END    
   END

Quit:

END

GO