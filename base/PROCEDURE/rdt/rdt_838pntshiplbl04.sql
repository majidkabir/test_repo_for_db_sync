SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**********************************************************************************/
/* Store procedure: rdt_838PntShipLbl04                                           */
/* Copyright      : Maersk                                                        */
/* Customer       : Granite                                                       */
/*                                                                                */
/* Date       Rev    Author     Purposes                                          */
/* 2024-07-05 1.0    JACKC      FCR-392 Print Carton labels                       */
/* 2024-07-22 1.1    JACKC      FCR-392 Change printing logic per v1.4 FBR        */
/* 2024-07-25 1.2    JACKC      FCR-392 Fix the issue found in FCR-386            */
/* 2024-07-25 1.3    JACKC      FCR-392 Change prnt logic                         */
/* 2024-09-11 1.4    JACKC      FCR-392 Handle special order                      */
/* 2024-09-30 1.5    NLT013     Fix printing special order labels issue           */
/* 2024-10-12 1.6.0  NLT013     FCR-955 PPA by LabelNo, instead of PickSLipNo     */
/* 2024-12-03 1.7.0  NLT013     FCR-1659 Be able to print label for MPOC          */
/**********************************************************************************/

CREATE   PROC rdt.rdt_838PntShipLbl04 (
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
            DECLARE  
               @cLabelName                NVARCHAR( 10),
               @cOrderKey                 NVARCHAR( 10),
               @cConsigneeKey             NVARCHAR( 15),
               @cBillToKey                NVARCHAR( 15),
               @cPrintSequence            NVARCHAR( 10),
               @cCustLblPrintSequence     NVARCHAR( 10),
               @cDefaultLblPrintSequence  NVARCHAR( 10),
               @cCustLabelName            NVARCHAR( 30),
               @cDefaultLabelName         NVARCHAR( 30),
               @cCustLabelDataDesc        NVARCHAR( 30),
               @cOrderGroup               NVARCHAR( 20),
               @cVASCode                  NVARCHAR( 12), --v1.4
               @cCode2                    NVARCHAR( 30), --v1.4
               @cCustomCode               NVARCHAR(30), --v1.4
               @nLoopIndex                INT,
               @nSpecialCartonLabelPrinted       INT = 0,
               @nSpecialVendorLabelPrinted       INT = 0,
               @nMPOCCarton               INT = 0,
               @nRowCount                 INT = 0

            DECLARE @cLabelPrinter     NVARCHAR( 10)
            DECLARE @cPaperPrinter     NVARCHAR( 10)
            DECLARE @cPrinterGroup     NVARCHAR( 10)
            DECLARE @bDebugFlag        BINARY = 0
            DECLARE @tCartonLabelList AS VariableTable

            -- Get session info
            SELECT 
               @cLabelPrinter = Printer,
               @cPaperPrinter = Printer_Paper
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            -- Get Order key
            SELECT 
               @cOrderKey = pkd.OrderKey
            FROM PickDetail pkd WITH (NOLOCK) 
            WHERE pkd.Storerkey = @cStorerKey AND pkd.CaseID = @cLabelNo

            -- Common params
            INSERT INTO @tCartonLabelList (Variable, Value) VALUES
            ( '@cStorerKey',     @cStorerKey),
            ( '@cOrderKey',      @cOrderKey),
            ( '@cLabelNo',       @cLabelNo)

            IF @bDebugFlag = 1
            BEGIN
               SELECT 'PrtinerGroup', @cPrinterGroup
               SELECT 'Params Table'
               SELECT * FROM @tCartonLabelList
            END

            --Prepare default labels
            DECLARE @tDefaultLabels TABLE
            (
               id             INT IDENTITY(1,1),
               code           NVARCHAR(30), --v1.4
               code2          NVARCHAR(30),
               UDF01          NVARCHAR(30),
               Short          NVARCHAR(10)
            )

            INSERT INTO @tDefaultLabels (code2, UDF01, Short, code)
               SELECT code2, UDF01, Short, code --v1.4
               FROM dbo.CODELKUP WITH(NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND LISTNAME = 'LVSCARTLBL'
                  AND ISNULL(Long, '') = 'A'
               ORDER BY ISNULL(Short, '99999')

            IF @bDebugFlag = 1
            BEGIN
               SELECT 'Default label list'
               SELECT * FROM @tDefaultLabels
            END

            --V1.4 start
            DECLARE @tCustWorkOrderLabels TABLE
            (
               id             INT IDENTITY(1,1),
               Type           NVARCHAR(12),
               UDF01          NVARCHAR(30),
               code2          NVARCHAR(30),
               PrintSequence  INT,
               IgnoreFlag     INT DEFAULT 0
            )

            INSERT INTO @tCustWorkOrderLabels (Type, UDF01, code2, PrintSequence)
               SELECT DISTINCT lk.Code, lk.UDF01, lk.code2, IIF(UPPER(LEFT(lk.code2, 4)) = 'MPOC', 1, 2)
               FROM dbo.WorkOrder wo WITH(NOLOCK)
               INNER JOIN dbo.WorkOrderDetail wod WITH(NOLOCK) ON wo.WorkOrderKey = wod.WorkOrderKey
               INNER JOIN dbo.PickDetail pkd WITH(NOLOCK) ON wod.StorerKey = pkd.StorerKey AND wod.ExternWorkOrderKey = pkd.OrderKey 
               INNER JOIN dbo.CODELKUP lk WITH(NOLOCK) ON wod.StorerKey = lk.StorerKey AND wod.Type = lk.Code AND lk.LISTNAME = 'LVSCARTLBL' AND ISNULL(wod.Remarks, '-1') = lk.code2
               WHERE wod.StorerKey = @cStorerKey
                  AND wod.Type <> ''
                  AND wod.ExternLineNo = ''
                  AND ISNULL(pkd.CaseID, '') = @cLabelNo
                  AND ISNULL(wod.Remarks, '') <> ''
               ORDER BY IIF(UPPER(LEFT(lk.code2, 4)) = 'MPOC', 1, 2)

            IF @bDebugFlag = 1
            BEGIN
               SELECT 'CustWorkOrderLabel List'
               SELECT * FROM @tCustWorkOrderLabels
            END

            SELECT @nRowCount = COUNT( DISTINCT CONCAT(ORM.BillToKey, ORM.ShipperKey, ORM.MarkforKey) )
            FROM dbo.PickDetail PKD WITH(NOLOCK)
            INNER JOIN dbo.ORDERS ORM WITH(NOLOCK)
               ON PKD.StorerKey = ORM.StorerKey 
               AND PKD.OrderKey = ORM.OrderKey
            WHERE PKD.StorerKey = @cStorerKey 
               AND ISNULL(PKD.CaseID, '') = @cLabelNo

            IF @nRowCount = 1
               SET @nMPOCCarton = 1
            
            SELECT @nRowCount = COUNT( DISTINCT OrderKey )
            FROM dbo.PickDetail WITH(NOLOCK)
            WHERE StorerKey = @cStorerKey 
               AND ISNULL(CaseID, '') = @cLabelNo

            IF @nRowCount < 2
               SET @nMPOCCarton = 0

            --Print Special Labels
            SET @nLoopIndex = -1
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1 
                  @cVASCode = Type,
                  @cLabelName = UDF01,
                  @cCode2 = code2,
                  @nLoopIndex = id
               FROM @tCustWorkOrderLabels
               WHERE id > @nLoopIndex
                  AND IgnoreFlag = 0
               ORDER BY id

               IF @@ROWCOUNT = 0
                  BREAK

               IF @nMPOCCarton = 1 AND LEFT(@cCode2, 4) = 'MPOC'
               BEGIN
                  IF UPPER(LEFT(@cCode2, 11)) = 'MPOCCONTENT'
                  BEGIN
                     DELETE FROM @tDefaultLabels WHERE LEFT(UDF01, 3) = 'CTN'
                     UPDATE @tCustWorkOrderLabels SET IgnoreFlag = 1 WHERE LEFT(Code2, 4) <> 'MPOC' AND LEFT(UDF01, 3) = 'CTN' AND id > @nLoopIndex
                     SET @nSpecialCartonLabelPrinted = 1
                  END
                  ELSE
                  BEGIN
                     DELETE FROM @tDefaultLabels WHERE LEFT(UDF01, 3) <> 'CTN'
                     UPDATE @tCustWorkOrderLabels SET IgnoreFlag = 1 WHERE LEFT(Code2, 4) <> 'MPOC' AND LEFT(UDF01, 3) <> 'CTN' AND id > @nLoopIndex
                     SET @nSpecialVendorLabelPrinted = 1
                  END
               END
               ELSE
               BEGIN
                  IF LEFT(@cCode2, 4) = 'MPOC'
                     CONTINUE
                  IF LEFT(@cLabelName, 3) = 'CTN'
                  BEGIN
                     DELETE FROM @tDefaultLabels WHERE (Code = @cVASCode OR code2 = @cCode2) AND LEFT(UDF01, 3) = 'CTN'
                     SET @nSpecialCartonLabelPrinted = 1
                  END
                  ELSE
                  BEGIN
                     DELETE FROM @tDefaultLabels WHERE (Code = @cVASCode OR code2 = @cCode2) AND LEFT(UDF01, 3) <> 'CTN'
                     SET @nSpecialVendorLabelPrinted = 1
                  END
               END

               IF @bDebugFlag = 1
               BEGIN
                  SELECT 'Delete from default label list', @cVASCode AS Code, @cCode2 AS Code2
                  SELECT 'Print workorder label', @nLoopIndex AS ID, @cLabelName AS Label
               END

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cLabelName, -- Report type
                  @tCartonLabelList, -- Report params
                  'rdt_838PntShipLbl04',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
               BEGIN
                  GOTO Quit
               END
            END

            IF @bDebugFlag = 1
            BEGIN
               SELECT 'Default Label List'
               SELECT * FROM @tDefaultLabels
            END
            --V1.4 END


            SELECT TOP 1 @cConsigneeKey = orm.ConsigneeKey,
               @cBillToKey = orm.BillToKey,
               @cOrderGroup = orm.OrderGroup
            FROM dbo.PickDetail pkd WITH(NOLOCK)
               INNER JOIN dbo.ORDERS orm WITH(NOLOCK) ON pkd.StorerKey = orm.StorerKey AND pkd.OrderKey = orm.OrderKey
            WHERE pkd.StorerKey = @cStorerKey
               AND ISNULL(pkd.CaseID, '') = @cLabelNo

            IF @bDebugFlag = 1
               SELECT 'Order Info', @cConsigneeKey AS ConsigneeKey, @cBillToKey AS BillToKey, @cOrderGroup AS OrderGroup

            --IF code2 equals to ConsigneeKey and BillToKey, only fetch data which code2 = @cConsigneeKey
            IF EXISTS (SELECT 1
                  FROM dbo.CODELKUP lk WITH(NOLOCK) 
                  INNER JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON lk.StorerKey = lk1.StorerKey AND lk.Code2 = ISNULL(lk1.Description, '') AND lk.Code = ISNULL(lk1.Long, '') 
                  WHERE lk.StorerKey = @cStorerKey
                     AND lk.LISTNAME = 'LVSCARTLBL' 
                     AND ISNULL(lk.Long, '') = ''
                     AND lk1.LISTNAME = 'LVSCUSPREF'
                     AND lk1.code2 = @cConsigneeKey)
               AND EXISTS (SELECT 1
                  FROM dbo.CODELKUP lk WITH(NOLOCK) 
                  INNER JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON lk.StorerKey = lk1.StorerKey AND lk.Code2 = ISNULL(lk1.Description, '') AND lk.Code = ISNULL(lk1.Long, '') 
                  WHERE lk.StorerKey = @cStorerKey
                     AND lk.LISTNAME = 'LVSCARTLBL' 
                     AND ISNULL(lk.Long, '') = ''
                     AND lk1.LISTNAME = 'LVSCUSPREF'
                     AND lk1.code2 = @cBillToKey)
            BEGIN
               DECLARE CUR_CARTONLABEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
                  FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND code2 = @cConsigneeKey
                        ) AS CustLabelData
                  LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A') AS CustLabels 
                     ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
                  ORDER BY ISNULL(CustLabels.Short, '99999')
            END
            ELSE 
               DECLARE CUR_CARTONLABEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
                  FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND (code2 = @cConsigneeKey OR code2 = @cBillToKey)
                        ) AS CustLabelData
                  LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A') AS CustLabels 
                     ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
                  ORDER BY ISNULL(CustLabels.Short, '99999')

            OPEN CUR_CARTONLABEL 
            FETCH NEXT FROM CUR_CARTONLABEL INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence,@cCustomCode

            WHILE @@FETCH_STATUS = 0 
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Label cursor record', @cCustLabelName AS CustomizedLabelName, @cCustLabelDataDesc AS LabelDesc, 
                     @cCustLblPrintSequence AS CustomPrintSequence, @cCustomCode AS CustomCode

               IF @cCustLabelName IS NOT NULL AND TRIM(@cCustLabelName) <> ''
                  AND   (  
                           (@nSpecialCartonLabelPrinted = 0 AND LEFT(@cCustLabelName, 3) = 'CTN' )
                           OR 
                           (@nSpecialVendorLabelPrinted = 0 AND LEFT(@cCustLabelName, 3) <> 'CTN') 
                        )
               BEGIN
                  -- If customized lable found, delete default label from the list
                  IF @bDebugFlag = 1
                     SELECT 'Delete Default Label List', @cCustLabelDataDesc AS Code2

                  DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
                  SET @cLabelName = @cCustLabelName

                  IF @bDebugFlag = 1
                     SELECT 'Print Label', @cLabelName, @cCustLblPrintSequence

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cLabelName, -- Report type
                     @tCartonLabelList, -- Report params
                     'rdt_838PntShipLbl04',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     CLOSE CUR_CARTONLABEL 
                     DEALLOCATE CUR_CARTONLABEL 

                     GOTO Quit
                  END
               END --Custom not null
               ELSE IF @cCustomCode = 'UNO'
               BEGIN
                  DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
                  IF @bDebugFlag = 1
                     SELECT 'Delete from default lables due to Cusotm Code = UNO', @cCustomCode AS CustomCode, @cCustLabelDataDesc AS CustomeLabelDataDesc
               END
               FETCH NEXT FROM CUR_CARTONLABEL INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence,@cCustomCode
            END-- end while

            IF @bDebugFlag = 1
               SELECT 'Close Cursor'

            CLOSE CUR_CARTONLABEL 
            DEALLOCATE CUR_CARTONLABEL

            --Print default lables
            IF @bDebugFlag = 1
            BEGIN
               SELECT 'Default Label list to Print'
               SELECT * FROM @tDefaultLabels
            END 

            SET @nLoopIndex = -1
            WHILE 1 = 1
            --AND @cOrderGroup = '10'
            BEGIN
               SELECT TOP 1 
                  @cLabelName = UDF01,
                  @nLoopIndex = id
               FROM @tDefaultLabels
                  WHERE id > @nLoopIndex
               ORDER BY id

               IF @@ROWCOUNT = 0
                  BREAK

               IF @bDebugFlag = 1
                  SELECT 'Print default label', @cLabelName, @nLoopIndex

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cLabelName, -- Report type
                  @tCartonLabelList, -- Report params
                  'rdt_838PntShipLbl04',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
                  
               IF @nErrNo <> 0
               BEGIN
                  GOTO Quit
               END
            END--Print default while
         END -- option 1
      END -- input key 1
   END --step5

   GOTO Quit 
 
   
   Quit:  
END

GO