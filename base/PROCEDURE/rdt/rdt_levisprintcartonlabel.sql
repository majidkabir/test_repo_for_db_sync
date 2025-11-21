SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure:   rdt_LevisPrintCartonLabel                         */
/* Copyright      :   Maersk                                            */
/*                                                                      */
/* Date        Rev    Author       Purposes                             */
/* 2025-02-05  1.0.0  CYU027   FCR-2630 Add Option=5 in step 5          */
/* 2025-02-12  1.0.1  CYU027   FCR-2630 Only print ZPL when option = 5  */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LevisPrintCartonLabel]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @nStep        INT,
   @nInputKey    INT,
   @cDropID      NVARCHAR( 20),
   @cPrintType   NVARCHAR( 20) = 'BARTENDER', --'ZPL' when print only ZPL
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cPickslipNo                        NVARCHAR( 10),
      @cVASCode                           NVARCHAR(20),
      @cLabelName                         NVARCHAR(30),
      @cCode2                             NVARCHAR(30),
      @cConsigneeKey                      NVARCHAR(15),
      @cBillToKey                         NVARCHAR(15),
      @cCustLblPrintSequence              NVARCHAR(10),
      @cFacility                          NVARCHAR(5),
      @cLabelPrinterGroup                 NVARCHAR(10),
      @cPaperPrinter                      NVARCHAR(10),
      @cCustLabelName                     NVARCHAR(30),
      @cCustLabelDataDesc                 NVARCHAR(30),
      @cCustomCode                        NVARCHAR(30),
      @cOrderGroup                        NVARCHAR(20) = '',
      @cOLPSDescription                   NVARCHAR(15) = 'OlpsPlacement',
      @nSpecialCartonLabelPrinted         INT = 0,
      @nSpecialVendorLabelPrinted         INT = 0,
      @nLoopIndex                         INT,
      @nRowCount                          INT,
      @nMPOCCarton                        INT = 0,
      @cUserName                          NVARCHAR( 20),
      @cCumLabelPrinterGroup              NVARCHAR(10)

   SELECT @cLabelPrinterGroup = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cCumLabelPrinterGroup = CASE WHEN @cPrintType = 'ZPL' THEN 'PANDA' ELSE @cLabelPrinterGroup END
 
   SELECT @nRowCount = COUNT( DISTINCT CONCAT(ORM.BillToKey, ORM.ShipperKey, ORM.MarkforKey) )
   FROM dbo.PickDetail PKD WITH(NOLOCK)
     INNER JOIN dbo.ORDERS ORM WITH(NOLOCK)
       ON PKD.StorerKey = ORM.StorerKey
          AND PKD.OrderKey = ORM.OrderKey
   WHERE PKD.StorerKey = @cStorerKey
     AND PKD.CaseID <> ''
     AND PKD.CaseID = @cDropID

   IF @nRowCount = 1
      SET @nMPOCCarton = 1

   SELECT @nRowCount = COUNT( DISTINCT OrderKey )
   FROM dbo.PickDetail WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
     AND CaseID <> ''
     AND CaseID = @cDropID

   IF @nRowCount < 2
      SET @nMPOCCarton = 0

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
     AND labelno = @cDropID

   DECLARE @tCartonLabelList VariableTable
   INSERT INTO @tCartonLabelList (Variable, Value)
   VALUES
      ( '@cPickSlipNo', @cPickSlipNo),
      ( '@cLabelNo', @cDropID),
      ( '@cPrintType', @cPrintType)

   DECLARE @tDefaultLabels TABLE
      (
         id             INT IDENTITY(1,1),
         Code           NVARCHAR(30),
         code2          NVARCHAR(30),
         UDF01          NVARCHAR(30),
         Short          NVARCHAR(10)
      )

   INSERT INTO @tDefaultLabels (code2, UDF01, Short, Code)
   SELECT code2, UDF01, Short, Code
   FROM dbo.CODELKUP WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
     AND LISTNAME = 'LVSCARTLBL'
     AND ISNULL(Long, '') = 'A'
   ORDER BY ISNULL(Short, '99999')

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
     AND pkd.CaseID <> ''
     AND pkd.CaseID = @cDropID
     AND ISNULL(wod.Remarks, '') <> ''
   ORDER BY IIF(UPPER(LEFT(lk.code2, 4)) = 'MPOC', 1, 2)

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

      --print automation no need to print normal labels
      IF (@cPrintType = 'ZPL' 
         AND EXISTS (SELECT 1 FROM RDT.RDTReporttoPrinter WITH(NOLOCK)
         WHERE Function_ID = @nFunc AND StorerKey = @cStorerKey AND PrinterID= 'PANDA' AND PrinterGroup = 'PANDA' AND ReportType = @cLabelName)
         ) OR @cPrintType <> 'ZPL' 
      BEGIN
         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCumLabelPrinterGroup, 
            @cPaperPrinter,
            @cLabelName, -- Report type
            @tCartonLabelList, -- Report params
            'rdt_855ExtUpd13',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END
      END
   END

   SELECT TOP 1 @cConsigneeKey = orm.ConsigneeKey,
                @cBillToKey = orm.BillToKey,
                @cOrderGroup = orm.OrderGroup
   FROM dbo.PickDetail pkd WITH(NOLOCK)
           INNER JOIN dbo.ORDERS orm WITH(NOLOCK) ON pkd.StorerKey = orm.StorerKey AND pkd.OrderKey = orm.OrderKey
   WHERE pkd.StorerKey = @cStorerKey
     AND pkd.CaseID <> ''
     AND pkd.CaseID = @cDropID

   --IF code2 equals to ConsigneeKey and BillToKey, only fetch data which code2 = @cConsigneeKey
   IF EXISTS (SELECT 1
              FROM dbo.CODELKUP lk WITH(NOLOCK)
                      INNER JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON lk.StorerKey = lk1.StorerKey AND lk.Code2 = ISNULL(lk1.Description, '') AND lk.Code = ISNULL(lk1.Long, '')
              WHERE lk.StorerKey = @cStorerKey
                AND lk.LISTNAME = 'LVSCARTLBL'
                AND ISNULL(lk.Long, '') = ''
                AND lk1.LISTNAME = 'LVSCUSPREF'
                AND ISNULL(lk1.Description, '') <> @cOLPSDescription
                AND lk1.code2 = @cConsigneeKey)
      AND EXISTS (SELECT 1
                  FROM dbo.CODELKUP lk WITH(NOLOCK)
                          INNER JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON lk.StorerKey = lk1.StorerKey AND lk.Code2 = ISNULL(lk1.Description, '') AND lk.Code = ISNULL(lk1.Long, '')
                  WHERE lk.StorerKey = @cStorerKey
                    AND lk.LISTNAME = 'LVSCARTLBL'
                    AND ISNULL(lk.Long, '') = ''
                    AND lk1.LISTNAME = 'LVSCUSPREF'
                    AND ISNULL(lk1.Description, '') <> @cOLPSDescription
                    AND lk1.code2 = @cBillToKey)
      BEGIN
         DECLARE CUR_CARTONLABEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
            FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND code2 = @cConsigneeKey AND ISNULL(Description, '') <> @cOLPSDescription
                                                                                                                 AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description)) AS CustLabelData
                    LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A'
            ) AS CustLabels
                              ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
            ORDER BY ISNULL(CustLabels.Short, '99999')
      END
   ELSE
      DECLARE CUR_CARTONLABEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
         FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF' AND ISNULL(Description, '') <> @cOLPSDescription AND (code2 = @cConsigneeKey OR code2 = @cBillToKey)
                                                                                                           AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description)) AS CustLabelData
                 LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A'
         ) AS CustLabels
                           ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
         ORDER BY ISNULL(CustLabels.Short, '99999')

   OPEN CUR_CARTONLABEL
   FETCH NEXT FROM CUR_CARTONLABEL INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence,@cCustomCode

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cCustLabelName IS NOT NULL AND TRIM(@cCustLabelName) <> ''
         AND (
            (@nSpecialCartonLabelPrinted = 0 AND LEFT(@cCustLabelName, 3) = 'CTN' )
               OR
            (@nSpecialVendorLabelPrinted = 0 AND LEFT(@cCustLabelName, 3) <> 'CTN')
            )
         BEGIN
            DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
            SET @cLabelName = @cCustLabelName
            --print automation no need to print normal labels
            IF (@cPrintType = 'ZPL' 
            AND EXISTS (SELECT 1 FROM RDT.RDTReporttoPrinter WITH(NOLOCK)
            WHERE Function_ID = @nFunc AND StorerKey = @cStorerKey AND PrinterID= 'PANDA' AND PrinterGroup = 'PANDA' AND ReportType = @cLabelName)
            ) OR @cPrintType <> 'ZPL' 
            BEGIN
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cCumLabelPrinterGroup, 
                  @cPaperPrinter,
                  @cLabelName, -- Report type
                  @tCartonLabelList, -- Report params
                  'rdt_855ExtUpd13',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  CLOSE CUR_CARTONLABEL
                  DEALLOCATE CUR_CARTONLABEL

                  GOTO Quit
               END
            END
         END
      ELSE IF @cCustomCode = 'UNO'
         BEGIN
            DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
         END
      FETCH NEXT FROM CUR_CARTONLABEL INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence,@cCustomCode
   END
   CLOSE CUR_CARTONLABEL
   DEALLOCATE CUR_CARTONLABEL

   --Print Default Labels
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
      --print automation no need to print normal labels
      IF (@cPrintType = 'ZPL' 
         AND EXISTS (SELECT 1 FROM RDT.RDTReporttoPrinter WITH(NOLOCK)
         WHERE Function_ID = @nFunc AND StorerKey = @cStorerKey AND PrinterID= 'PANDA' AND PrinterGroup = 'PANDA' AND ReportType = @cLabelName)
         ) OR @cPrintType <> 'ZPL' 
      BEGIN
         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cCumLabelPrinterGroup, 
            @cPaperPrinter,
            @cLabelName, -- Report type
            @tCartonLabelList, -- Report params
            'rdt_855ExtUpd13',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END
      END
   END


   Quit:
END

GO