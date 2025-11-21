SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593CatalogLabel01                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-02-07 1.0  NLT03      FCR-727 Create                                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593CatalogLabel01] (
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
      @cSKU                      NVARCHAR( 20),
      @nQty                      INT,
      @nLoopIndex                INT,
      @nRowCount                 INT,
      @tCatelogLabelList           VariableTable,
      @cPickSlipNo               NVARCHAR( 10),
      @cLabelPrinterGroup        NVARCHAR( 10),
      @cPaperPrinter             NVARCHAR( 10),
      @cPickConfirmStatus        NVARCHAR( 1),
      @cLabelName                NVARCHAR( 30),
      @cFacility                 NVARCHAR( 5)

   SET @cDropID = ISNULL(@cParam1, '')
   SET @cSKU = ISNULL(@cParam2, '')
   SET @nQty = TRY_CAST(@cParam3 AS INT)
   
   SET @nQty = IIF(@nQty IS NULL, 0, @nQty)

   DECLARE @tLabels TABLE
   (
      ID    INT IDENTITY(1,1),
      LabelName                  NVARCHAR(30),
      PrintSequence              NVARCHAR(5)
   )

   SELECT 
      @cLabelPrinterGroup = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   IF TRIM(@cDropID) = ''
   BEGIN
      SET @nErrNo = 222351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNoNeeded
      GOTO Quit
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PKD WITH(NOLOCK)
                  INNER JOIN RDT.RDTPPA PPA WITH(NOLOCK) ON PKD.StorerKey = PPA.StorerKey AND ISNULL(PKD.CaseID, '') = PPA.DropID AND PKD.Sku = PPA.Sku
                  WHERE PKD.StorerKey = @cStorerKey
                     AND ISNULL(PKD.CaseID, '') = @cDropID
                     AND PPA.Status = '5'
                     AND pkd.Status >= @cPickConfirmStatus)
   BEGIN
      SET @nErrNo = 222352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo
      GOTO Quit
   END

   IF TRIM(@cSKU) = ''
   BEGIN
      SET @nErrNo = 222353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNeeded
      GOTO Quit
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PKD WITH(NOLOCK)
                  INNER JOIN RDT.RDTPPA PPA WITH(NOLOCK) ON PKD.StorerKey = PPA.StorerKey AND ISNULL(PKD.CaseID, '') = PPA.DropID AND PKD.Sku = PPA.Sku
                  WHERE PKD.StorerKey = @cStorerKey
                     AND ISNULL(PKD.CaseID, '') = @cDropID
                     AND PPA.Status = '5'
                     AND PPA.Sku = @cSKU
                     AND pkd.Status >= @cPickConfirmStatus)
   BEGIN
      SET @nErrNo = 222354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
      GOTO Quit
   END

   IF @nQty < 1
   BEGIN
      SET @nErrNo = 222355
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidQty
      GOTO Quit
   END

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH(NOLOCK) 
   WHERE StorerKey = @cStorerKey 
   AND labelno = @cDropID

   INSERT INTO @tLabels (LabelName, PrintSequence)
   SELECT DISTINCT IIF(lk1.LISTNAME IS NULL, lk.UDF01, lk1.UDF01), lk.Code
   FROM (SELECT StorerKey, WorkOrderKey, ExternWorkOrderKey, ExternLineNo, WorkOrderLineNumber, Type
         FROM
            (SELECT 
               wod1.StorerKey, wod1.WorkOrderKey, wod1.ExternWorkOrderKey, wod1.ExternLineNo, wod1.WorkOrderLineNumber, wod1.Type, 
               ROW_NUMBER()OVER(PARTITION BY WorkOrderKey, ExternWorkOrderKey, ExternLineNo ORDER BY WorkOrderKey, ExternWorkOrderKey, ExternLineNo) AS ROW# 
               FROM dbo.WorkOrderDetail wod1 WITH(NOLOCK)
               INNER JOIN dbo.CODELKUP lk2 WITH(NOLOCK) ON wod1.StorerKey = lk2.StorerKey AND lk2.LISTNAME = 'WKORDTYPE' AND lk2.UDF04 = 'LVSCatalog' AND wod1.Type = lk2.Code
               WHERE wod1.StorerKey = @cStorerKey
                  AND TRIM(wod1.Type) <> ''
                  AND TRIM(wod1.ExternLineNo) <> '') AS t
         WHERE ROW# = 1) AS wod
   INNER JOIN dbo.WorkOrder wo WITH(NOLOCK) ON wo.WorkOrderKey = wod.WorkOrderKey
   INNER JOIN dbo.ORDERS orm WITH(NOLOCK) ON wod.StorerKey = orm.StorerKey AND ISNULL(wod.ExternWorkOrderKey, '') = orm.OrderKey
   INNER JOIN dbo.CODELKUP lk WITH(NOLOCK) ON wo.StorerKey = lk.StorerKey AND wod.Type = lk.Code AND lk.LISTNAME = 'WKORDTYPE' AND lk.UDF04 = 'LVSCatalog' 
   INNER JOIN dbo.PickDetail pkd WITH(NOLOCK) ON wo.StorerKey = pkd.StorerKey AND ISNULL(wod.ExternWorkOrderKey, '') = pkd.OrderKey AND pkd.OrderLinenumber = wod.ExternLineNo AND pkd.Status >= @cPickConfirmStatus
   INNER JOIN dbo.PackDetail pakd WITH(NOLOCK) ON pkd.StorerKey = pakd.StorerKey AND ISNULL(pkd.CaseID, '') = pakd.LabelNo AND pakd.SKU = pkd.SKU
   LEFT JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON lk.StorerKey = lk1.StorerKey AND lk.Code = lk1.Code AND lk.UDF04 = lk1.LISTNAME AND lk1.Code2 <> ''
      AND (orm.ConsigneeKey = lk1.Code2 OR  MarkforKey = lk1.Code2 OR BillToKey = lk1.Code2)
   WHERE wo.StorerKey = @cStorerKey
      AND pkd.Sku = @cSKU
      AND ISNULL(pkd.CaseID, '') = @cDropID
      AND wod.ExternLineNo <> ''
   ORDER BY lk.Code ASC

   SET @nLoopIndex = -1
   WHILE 1 = 1
   BEGIN
      SELECT TOP 1 
         @cLabelName = LabelName,
         @nLoopIndex = id
      FROM @tLabels
      WHERE id > @nLoopIndex
      ORDER BY id

      SELECT @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
         BREAK

      DELETE FROM @tCatelogLabelList

      INSERT INTO @tCatelogLabelList (Variable, Value) 
      VALUES 
         ( '@cPickSlipNo', @cPickSlipNo),
         ( '@cLabelNo', @cDropID),
         ( '@cSKU', @cSKU)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
         @cLabelName, -- Report type
         @tCatelogLabelList, -- Report params
         'rdt_593CatalogLabel01',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @nNoOfCopy = @nQty

      IF @nErrNo <> 0
      BEGIN
         GOTO Quit
      END
   END
  
Fail:
   RETURN
Quit:

GO