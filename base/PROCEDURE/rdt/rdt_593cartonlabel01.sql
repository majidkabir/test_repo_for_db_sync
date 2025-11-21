SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdt_593CartonLabel01                                        */
/*                                                                              */
/* Customer: Granite                                                            */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2018-02-07 1.0    NLT03      FCR-727 Create                                  */
/* 2024-10-12 1.2.0  NLT013     FCR-955 PPA by LabelNo, instead of PickSLipNo   */
/* 2024-12-03 1.3.0  NLT013     FCR-1659 Be able to print label for MPOC        */
/* 2024-12-03 1.3.1  NLT013     FCR-1659 Unable to reprint new carton           */
/********************************************************************************/

CREATE   PROC [RDT].[rdt_593CartonLabel01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2), 
   @cParam1    NVARCHAR(60), 
   @cParam2    NVARCHAR(60), 
   @cParam3    NVARCHAR(60), 
   @cParam4    NVARCHAR(60), 
   @cParam5    NVARCHAR(60), 
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cDropID                   NVARCHAR( 20),
      @cConsigneeKey             NVARCHAR(15),
      @cBillToKey                NVARCHAR(15),
      @cCustLblPrintSequence     NVARCHAR(10),
      @cDefaultLblPrintSequence  NVARCHAR(10),
      @cCustLabelName            NVARCHAR(30),
      @cDefaultLabelName         NVARCHAR(30),
      @cCustLabelDataDesc        NVARCHAR(30),
      @cCustomCode               NVARCHAR(30),
      @cPickConfirmStatus        NVARCHAR( 1),
      @cLabelPrinterGroup        NVARCHAR( 10),
      @cLabelName                NVARCHAR( 30),
      @cPaperPrinter             NVARCHAR( 10),
      @cFacility                 NVARCHAR( 5),
      @cVASCode                  NVARCHAR(20),
      @cCode2                    NVARCHAR(30),
      @tCartonLabelList          VariableTable,
      @nDefaultLabelQty          INT,
      @nCustomizeLabelQty        INT,
      @nCustWorkOrderLabelQty    INT,
      @nLoopIndex                INT,
      @nRowCount                 INT,
      @nMPOCCarton               INT

   
   DECLARE @tDefaultLabels TABLE
   (
      id             INT IDENTITY(1,1),
      Code           NVARCHAR(30),
      code2          NVARCHAR(30),
      UDF01          NVARCHAR(30),
      Short          NVARCHAR(10)
   )

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   SET @cDropID = ISNULL(@cParam1, '')

   SELECT 
      @cLabelPrinterGroup = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF TRIM(@cDropID) = ''
   BEGIN
      SET @nErrNo = 222401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNoNeeded
      GOTO Quit
   END

   IF LEN(@cDropID) = 20 AND LEFT(@cDropID, 2) = '00'
      SET @cDropID = RIGHT(@cDropID, 18)

   IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH(NOLOCK)
                  INNER JOIN dbo.PackHeader PH WITH(NOLOCK)
                     ON PD.PickSlipNo = PH.PickSlipNO
                     AND PD.StorerKey = PH.StorerKey
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.LabelNo = @cDropID
                     AND PH.Status = '9')
   BEGIN
      SET @nErrNo = 222402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo
      GOTO Quit
   END

   SELECT @nRowCount = COUNT( DISTINCT CONCAT(ORM.BillToKey, ORM.ShipperKey, ORM.MarkforKey) )
   FROM dbo.PickDetail PKD WITH(NOLOCK)
   INNER JOIN dbo.ORDERS ORM WITH(NOLOCK)
      ON PKD.StorerKey = ORM.StorerKey 
      AND PKD.OrderKey = ORM.OrderKey
   WHERE PKD.StorerKey = @cStorerKey 
      AND ISNULL(PKD.CaseID, '') = @cDropID

   IF @nRowCount = 1
      SET @nMPOCCarton = 1
   
   SELECT @nRowCount = COUNT( DISTINCT OrderKey )
   FROM dbo.PickDetail WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey 
      AND ISNULL(CaseID, '') = @cDropID

   IF @nRowCount < 2
      SET @nMPOCCarton = 0

   INSERT INTO @tCartonLabelList (Variable, Value) 
   VALUES 
         ( '@cLabelNo', @cDropID)

   INSERT INTO @tDefaultLabels (code2, UDF01, Short, Code)
   SELECT code2, UDF01, Short, Code
   FROM dbo.CODELKUP WITH(NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND LISTNAME = 'LVSCARTLBL'
      AND ISNULL(Long, '') = 'A'
      AND LEFT(UDF01, 3) = 'CTN'
   ORDER BY ISNULL(Short, '99999')

   SELECT @nDefaultLabelQty = COUNT(1) FROM @tDefaultLabels

   DECLARE @tCustWorkOrderLabels TABLE
   (
      id             INT IDENTITY(1,1),
      Type           NVARCHAR(12),
      UDF01          NVARCHAR(30),
      code2          NVARCHAR(30),
      PrintSequence  INT
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
      AND ISNULL(pkd.CaseID, '') = @cDropID
      AND ISNULL(wod.Remarks, '') <> ''
      AND CHARINDEX('CONTENT', lk.code2) > 0
   ORDER BY IIF(UPPER(LEFT(lk.code2, 4)) = 'MPOC', 1, 2)

   SELECT @nCustWorkOrderLabelQty = COUNT(1) FROM @tCustWorkOrderLabels

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
      ORDER BY id

      IF @@ROWCOUNT = 0
         BREAK

      IF @nMPOCCarton = 1 AND LEFT(@cCode2, 4) <> 'MPOC'
         CONTINUE

      IF @nMPOCCarton = 0 AND LEFT(@cCode2, 4) = 'MPOC'
         CONTINUE

      DELETE FROM @tDefaultLabels WHERE Code = @cVASCode OR code2 = @cCode2

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
         @cLabelName, -- Report type
         @tCartonLabelList, -- Report params
         'rdt_593CartonLabel01',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
      -- Only print 1 carton label
      GOTO Quit
   END

   SELECT TOP 1 @cConsigneeKey = orm.ConsigneeKey,
      @cBillToKey = orm.BillToKey
   FROM dbo.PickDetail pkd WITH(NOLOCK)
   INNER JOIN dbo.ORDERS orm WITH(NOLOCK) ON pkd.StorerKey = orm.StorerKey AND pkd.OrderKey = orm.OrderKey
   WHERE pkd.StorerKey = @cStorerKey
      AND pkd.Status >= @cPickConfirmStatus
      AND ISNULL(pkd.CaseID, '') = @cDropID

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
      DECLARE CUR_CARTONLABEL_REPRINT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
         FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND code2 = @cConsigneeKey
               AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description) ) AS CustLabelData
         LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A' AND LEFT(UDF01, 3) = 'CTN' ) AS CustLabels 
            ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
         ORDER BY ISNULL(CustLabels.Short, '99999')

      SELECT @nCustomizeLabelQty = COUNT(CustLabels.UDF01)
      FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND code2 = @cConsigneeKey
               AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description) ) AS CustLabelData
      LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A' AND LEFT(UDF01, 3) = 'CTN') AS CustLabels 
         ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
   END
   ELSE 
   BEGIN
      DECLARE CUR_CARTONLABEL_REPRINT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CustLabelData.Description, CustLabels.UDF01 AS CustLabelType, ISNULL(CustLabels.Short, '99999') AS CustSequence, CustLabelData.Long
         FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND (code2 = @cConsigneeKey OR code2 = @cBillToKey)
               AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description) ) AS CustLabelData
         LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A' AND LEFT(UDF01, 3) = 'CTN') AS CustLabels 
            ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
         ORDER BY ISNULL(CustLabels.Short, '99999')

      SELECT @nCustomizeLabelQty = COUNT(CustLabels.UDF01)
      FROM (SELECT StorerKey, Description, ISNULL(Long, '') AS Long FROM dbo.CODELKUP AS LK WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCUSPREF'  AND (code2 = @cConsigneeKey OR code2 = @cBillToKey)
            AND NOT EXISTS (SELECT 1 FROM @tCustWorkOrderLabels AS CWOL WHERE CWOL.Type = LK.Long OR CWOL.code2 = LK.Description)) AS CustLabelData
      LEFT JOIN (SELECT StorerKey, code2, Code, UDF01, Short FROM dbo.CODELKUP WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND LISTNAME = 'LVSCARTLBL'  AND ISNULL(Long, '') <> 'A' AND LEFT(UDF01, 3) = 'CTN') AS CustLabels 
         ON CustLabelData.StorerKey = CustLabels.StorerKey AND CustLabelData.Description = CustLabels.code2 AND CustLabelData.Long = CustLabels.Code
   END

   IF ISNULL( @nCustomizeLabelQty, 0 ) + ISNULL(@nDefaultLabelQty, 0) + ISNULL(@nCustWorkOrderLabelQty, 0) = 0
   BEGIN
      SET @nErrNo = 222403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrint
      DEALLOCATE CUR_CARTONLABEL_REPRINT 
      GOTO Quit
   END

   OPEN CUR_CARTONLABEL_REPRINT 
   FETCH NEXT FROM CUR_CARTONLABEL_REPRINT INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence, @cCustomCode

   WHILE @@FETCH_STATUS = 0 
   BEGIN
      IF @cCustLabelName IS NOT NULL AND TRIM(@cCustLabelName) <> ''
      BEGIN
         DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
         SET @cLabelName = @cCustLabelName
         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
            @cLabelName, -- Report type
            @tCartonLabelList, -- Report params
            'rdt_593CartonLabel01',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

            -- Only print 1 carton label
            CLOSE CUR_CARTONLABEL_REPRINT 
            DEALLOCATE CUR_CARTONLABEL_REPRINT 
            GOTO Quit
      END
      ELSE IF @cCustomCode = 'UNO'
      BEGIN
         DELETE FROM @tDefaultLabels WHERE code2 = @cCustLabelDataDesc
      END
      FETCH NEXT FROM CUR_CARTONLABEL_REPRINT INTO @cCustLabelDataDesc, @cCustLabelName, @cCustLblPrintSequence, @cCustomCode
   END
   CLOSE CUR_CARTONLABEL_REPRINT 
   DEALLOCATE CUR_CARTONLABEL_REPRINT 

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

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
         @cLabelName, -- Report type
         @tCartonLabelList, -- Report params
         'rdt_593CartonLabel01',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
         
      -- Only print 1 carton label
      GOTO Quit
   END

Fail:
   RETURN
Quit:

GO