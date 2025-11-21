SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838PntShipLbl02                                       */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 27-05-2024 1.0  NLT013     UWP-20090 Merge code to V2 branch,              */
/*                            original owner is Wojciech                      */
/******************************************************************************/

CREATE   PROC rdt.rdt_838PntShipLbl02 (
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
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   IF @nStep = 5 -- Print label
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cOption = 1 -- Yes
         BEGIN
            -- Get storer config
            DECLARE @cOrderKey         NVARCHAR( 20)
            DECLARE @cConsigneyKey     NVARCHAR( 20)
            DECLARE @cShipLabel        NVARCHAR( 10)
            DECLARE @tMultiLbl AS VariableTable
            DECLARE @cLabelPrinter     NVARCHAR( 10)
            DECLARE @cPaperPrinter     NVARCHAR( 10)
            DECLARE @OrderInfo         NVARCHAR( 20)   --WSE016
            DECLARE @SKUCount          INT            --WSE016
            -- Get session info
            SELECT 
               @cLabelPrinter = Printer, 
               @cPaperPrinter = Printer_Paper
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile 
            /*Recovery Order*/
            SELECT top 1 @cOrderKey = ph.OrderKey 
               FROM PackHeader ph WITH (NOLOCK) 
               JOIN PackDetail pd WITH (NOLOCK)
               ON ph.StorerKey = pd.StorerKey
               AND pd.PickSlipNo = ph.PickSlipNo
            WHERE ph.StorerKey = @cStorerKey
               AND pd.LabelNo = @cLabelNo
            /*   
            Recovery consigney Key from order
            */
            SELECT TOP 1 @cConsigneyKey = ConsigneeKey
            FROM ORDERS WITH(NOLOCK) 
            WHERE Orders.orderKey = @cOrderKey
            /*WS -  get OrderInfo Details */
            SELECT TOP 1 @OrderInfo = OI.OrderInfo03  
            FROM OrderInfo OI WITH(NOLOCK) 
            INNER JOIN ORDERS OM  WITH(NOLOCK) on OI.orderkey = OM.orderkey
            WHERE storerkey = @cStorerKey
               AND OM.orderKey = @cOrderKey
            /*    WS - get info for  Wickes label   */
            SELECT @SKUCount = count(pd.sku) from PackDetail pd WITH(NOLOCK)
            INNER JOIN PackHeader ph WITH(NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
            INNER JOIN ORDERS OM WITH(NOLOCK) ON OM.StorerKey = PH.StorerKey and OM.OrderKey = PH.OrderKey
            WHERE ph.StorerKey = @cStorerKey
               AND ph.OrderKey =  @cOrderKey
               AND OM.ConsigneeKey ='H25800830'  --WSE016: this is Wickes ConsigneeKey
               GROUP BY pd.DropID
            /*
            * Recovery_Ship_Label
            */
            --WSE016 start
            /* Wickes labels */
            IF @cConsigneyKey ='H25800830' and @SKUCount =1
            BEGIN
               SELECT TOP 1 @cShipLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND short = 'SINGLE_SKU'
            END 

            IF @cConsigneyKey ='H25800830' and @SKUCount >1
            BEGIN
               SELECT TOP 1 @cShipLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND short = 'MULTI_SKU'
            END 
            /* B&Q Labels */
            IF @OrderInfo = 'DC'
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cShipLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND short = @OrderInfo
            END 

            IF @OrderInfo = 'RCC'
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cShipLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND short = @OrderInfo
            END 
            --WSE016 end
            /* Other Labels */
            IF @OrderInfo NOT IN ('DC','RCC') and (@cConsigneyKey IS NULL OR @cConsigneyKey = '')   --WSE016
            BEGIN
               --Recovery default Label for storer Key
               SELECT TOP 1 @cShipLabel =  Code2
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND code = 'DEFAULT_LABEL'
            END
            ELSE 
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cShipLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLbl'
                  AND storerkey = @cStorerKey
                  AND code = @cConsigneyKey
              and Code <> 'H650004'               --WSE016
            END 
            -- Common params
            INSERT INTO @tMultiLbl (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cFromDropID',    @cFromDropID), -->
               ( '@cPackDtlDropID', @cPackDtlDropID),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))
            -- Print label
            --WSE016: for B&Q only -> this Customer will require to print 2 labels twice (4 in total)
            IF @OrderInfo  in ('DC','RCC')
            BEGIN
               --first printout
               EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  @cShipLabel, -- Report type
                  @tMultiLbl, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  'ShpLbl03', -- Report type
                  @tMultiLbl, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
               -- second printout
               EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  @cShipLabel, -- Report type
                  @tMultiLbl, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  'ShpLbl03', -- Report type
                  @tMultiLbl, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
            -- WSE016: Other Labels   
            IF @OrderInfo not  in ('DC','RCC')
            BEGIN
               EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  @cShipLabel, -- Report type
                  @tMultiLbl, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
   END
Quit:
END

GO