SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_593ExtPrntHQLbl                                 */
/* Copyright      : Maersk                                              */
/* Purpose: Re Print  Husqvarna Shipping Pallet Label                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date           Rev  Author     Purposes                              */
/* 16-May-2024    1.0  AGA399     Created                               */
/*                                                                      */
/************************************************************************/

CREATE     PROC [RDT].[rdt_593ExtPrntHQLbl] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR(3),
   @cStorerKey NVARCHAR(15),
   @cOption    NVARCHAR(1),
   @cParam1    NVARCHAR(20), --SSCC
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cUserName         NVARCHAR( 18),
           @cFacility         NVARCHAR( 5),
           @cShippLabel       NVARCHAR( 10),
           @cPalletLabel      NVARCHAR( 20),
           @cOrd_TrackNo      NVARCHAR( 40),
           @cExternOrderKey   NVARCHAR( 50),
           @cFileName         NVARCHAR( 50),
           @cOrderKey         NVARCHAR( 20),
           @cConsigneyKey     NVARCHAR( 20),
           @cShipLabel        NVARCHAR( 10),
           @tMultiLbl AS VariableTable,
           @OrderInfo         NVARCHAR( 20),  --WSE016
           @SKUCount          INT,            --WSE016
           @LOADKEY           NVARCHAR( 10),  --AGA399
           @PICKSLIP          NVARCHAR( 10),  --AGA399
           @dOrderDate        DATETIME,
           @nExpectedQty      INT = 0,
           @nPackedQty        INT = 0,
           @nTempCartonNo     INT
         , @nInputKey         INT = 1 -- Temp Fix

   DECLARE @tSSCCList VariableTable

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cStorerkey = StorerKey,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Insert test
INSERT INTO [dbo].[TraceInfo]
           ([TraceName]
           ,[TimeIn]
           ,[TimeOut]
           ,[TotalTime]
           ,[Step1]
           ,[Step2]
           ,[Step3]
           ,[Step4]
           ,[Step5]
           ,[Col1]
           ,[Col2]
           ,[Col3]
           ,[Col4]
           ,[Col5])
     Select N'rdt_593ExtPrntHQLbl'
           ,NULL
           ,NULL
           ,NULL
           ,@nStep
           ,@nMobile
           ,@nFunc
           ,@cLabelPrinter
           ,@cPaperPrinter
           ,@cFacility
           ,@cStorerkey
           ,NULL
           ,NULL
           ,NULL

   IF @nInputKey = 1
   BEGIN
      IF @nStep IN (1, 2) --Temp Fix
      BEGIN

        IF @cOption = '1'   -- added for 9nd label
        /*Recovery Order*/
            SELECT top 1 @cOrderKey = ph.OrderKey 
               FROM PackHeader ph WITH (NOLOCK) 
               JOIN PackDetail pd WITH (NOLOCK)
               ON ph.StorerKey = pd.StorerKey
               AND pd.PickSlipNo = ph.PickSlipNo
            WHERE ph.StorerKey = @cStorerKey
               AND pd.DropID = @cParam1
            
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
         /*    WS - get info for  Wickes and Screwfix label   */
            SELECT @SKUCount = count(distinct pd.sku) from PackDetail pd WITH(NOLOCK)
            INNER JOIN PackHeader ph WITH(NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
            INNER JOIN ORDERS OM WITH(NOLOCK) ON OM.StorerKey = PH.StorerKey and OM.OrderKey = PH.OrderKey
            WHERE ph.StorerKey = @cStorerKey
               AND ph.OrderKey =  @cOrderKey
            AND pd.DropID = @cParam1 --To filter for DropID in case in same SO there are pack DropID multi and LPn monoref
               AND (OM.ConsigneeKey ='H25800830' OR OM.ConsigneeKey ='H25800856' OR OM.ConsigneeKey ='H25800615') --WSE016: this is Wickes and Screwfix ConsigneeKey
               GROUP BY pd.DropID   
         /*
            * Recovery_Ship_Label
            */
            --WSE016 start
            /* Wickes labels */
            IF @cConsigneyKey ='H25800830' and @SKUCount =1
            BEGIN
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = 'SINGLE_SKU'
              AND code = 'H25800830'
            END

         IF @cConsigneyKey ='H25800830' and @SKUCount <>1
            BEGIN
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = 'MULTI_SKU'
              AND code = 'H25800830'
            END

         /* Screwfix labels */
            IF (@cConsigneyKey ='H25800856' OR @cConsigneyKey ='H25800615') and @SKUCount =1
            BEGIN
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = 'SINGLE_SKU'
              AND (code = 'H25800856' or code = 'H25800615')
            END

            IF (@cConsigneyKey ='H25800856' OR @cConsigneyKey ='H25800615') and @SKUCount <>1
            BEGIN
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = 'MULTI_SKU'
              AND (code = 'H25800856' or code = 'H25800615')
            END
         /* B&Q Labels */
            IF @OrderInfo = 'DC'
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = @OrderInfo
            END 

         IF @OrderInfo = 'RCC'
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND short = @OrderInfo
            END
         --WSE016 end
            /* Other Labels */
            IF @OrderInfo NOT IN ('DC','RCC') and (@cConsigneyKey IS NULL OR @cConsigneyKey = ''OR @cConsigneyKey not in ('H25800830','H25800856','H650004','H25800607','H25800615','H25800601'))   --WSE016
            BEGIN
               --Recovery default Label for storer Key
               SELECT TOP 1 @cPalletLabel =  Code2
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND code = 'DEFAULT_LABEL'
            END   
         ELSE 
            BEGIN
               --Recovery Consigney Key Label name
               SELECT TOP 1 @cPalletLabel = Code2 
               FROM CODELKUP WITH (NOLOCK) 
               WHERE listname = 'MultiLblR'
                  AND storerkey = @cStorerKey
                  AND code = @cConsigneyKey
                  and Code <> 'H650004'               --WSE016
              and Code <> 'H25800830'             --AGA399
              and Code <> 'H25800856'             --AGA399
              and Code <> 'H25800615'             --AGA399
            END   

         IF @cPalletLabel = '0'
            SET @cPalletLabel = ''

         -- TH use this to print outbound label by sscc
         IF @cPalletLabel <> ''
         BEGIN
            INSERT INTO @tSSCCList (Variable, Value) VALUES
            ( '@cStorerKey',  @cStorerKey),
            ( '@cSSCC',       @cParam1)

            -- Print label
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
                  @cPalletLabel, -- Report type
                  @tSSCCList, -- Report params
                  'rdt_593ExtPrntHQLbl',
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
                  'RShpLbl03', -- Report type
                  @tSSCCList, -- Report params
                  'rdt_593ExtPrntHQLbl',
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
                  @cPalletLabel, -- Report type
                  @tSSCCList, -- Report params
                  'rdt_593ExtPrntHQLbl',
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
                  'RShpLbl03', -- Report type
                  @tSSCCList, -- Report params
                  'rdt_593ExtPrntHQLbl',
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
                  @cPalletLabel, -- Report type
                  @tSSCCList, -- Report params
                  'rdt_593ExtPrntHQLbl',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         /*DropID update section*/
         
         IF @nErrNo = 0
         BEGIN
            SET @LOADKEY = (SELECT TOP 1 LoadKey FROM ORDERS (NOLOCK) WHERE orderkey = (SELECT TOP 1 OrderKey FROM PICKDETAIL (NOLOCK) WHERE DropID = @cParam1))
            
            SET @PICKSLIP = (SELECT TOP 1 PickSlipNo FROM PackDetail (NOLOCK) WHERE DropID = @cParam1)
            
            IF NOT EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cParam1)
            BEGIN
               INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,AddDate,AddWho,EditDate,EditWho,TrafficCop,ArchiveCop,Loadkey,PickSlipNo,UDF01,UDF02,UDF03,UDF04,UDF05)
               VALUES(@cParam1,'','',0,'Y',0,5,GETDATE(),SUSER_NAME(),GETDATE(),SUSER_NAME(),null,null,@LOADKEY,@PICKSLIP,'','','','','')
            END
            ELSE IF EXISTS (SELECT 1 FROM dropid (NOLOCK) WHERE dropid = @cParam1)
            BEGIN
               UPDATE dropid
               SET LabelPrinted = 'Y'
               WHERE dropid = @cParam1
            END
         END
         ELSE
         BEGIN
            GOTO Quit
         END
         END
      END   -- IF @nStep = 1
  END
Quit:
END

GO