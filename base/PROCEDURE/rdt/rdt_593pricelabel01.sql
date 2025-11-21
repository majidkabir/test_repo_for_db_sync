SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdt_593PriceLabel01                                         */
/* Customer: Granite                                                            */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2018-02-07 1.0    NLT03      FCR-727 Create                                  */
/* 2024-10-12 1.2.0  NLT013     FCR-955 PPA by LabelNo, instead of PickSLipNo   */
/********************************************************************************/

CREATE   PROC [RDT].[rdt_593PriceLabel01] (
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
      @tPriceLabelList           VariableTable,
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
      LabelName                  NVARCHAR(30)
   )

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   IF TRIM(@cDropID) = ''
   BEGIN
      SET @nErrNo = 222251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNoNeeded
      GOTO Quit
   END

   IF LEN(@cDropID) = 20 AND LEFT(@cDropID, 2) = '00'
      SET @cDropID = RIGHT(@cDropID, 18)

   IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PKD WITH(NOLOCK)
                  INNER JOIN RDT.RDTPPA PPA WITH(NOLOCK) ON PKD.StorerKey = PPA.StorerKey AND ISNULL(PKD.CaseID, '') = PPA.DropID AND PKD.Sku = PPA.Sku
                  WHERE PKD.StorerKey = @cStorerKey
                     AND ISNULL(PKD.CaseID, '') = @cDropID
                     AND PPA.Status = '5'
                     AND pkd.Status >= @cPickConfirmStatus)
   BEGIN
      SET @nErrNo = 222252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo
      GOTO Quit
   END

   IF TRIM(@cSKU) = ''
   BEGIN
      SET @nErrNo = 222253
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
      SET @nErrNo = 222254
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
      GOTO Quit
   END

   IF @nQty < 1
   BEGIN
      SET @nErrNo = 222255
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidQty
      GOTO Quit
   END

   SELECT 
      @cLabelPrinterGroup = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   INSERT INTO @tLabels(LabelName)
   SELECT DISTINCT IIF(wodEX.UDF01 IS NULL, lk.UDF01, wodEX.UDF01)
   FROM dbo.WorkOrderDetail wod  WITH(NOLOCK)
   INNER JOIN dbo.WorkOrder wo WITH(NOLOCK) ON wo.WorkOrderKey = wod.WorkOrderKey
   INNER JOIN dbo.CODELKUP lk WITH(NOLOCK) ON wo.StorerKey = lk.StorerKey AND wod.Type = lk.Code AND lk.LISTNAME = 'WKORDTYPE' AND lk.UDF04 = 'LVSPRICELB'
   INNER JOIN dbo.PickDetail pkd WITH(NOLOCK) ON wo.StorerKey = pkd.StorerKey AND ISNULL(wod.ExternWorkOrderKey, '') = pkd.OrderKey AND pkd.OrderLinenumber = wod.ExternLineNo AND pkd.Status >= @cPickConfirmStatus
   LEFT JOIN (SELECT DISTINCT lk1.LISTNAME, wod1.StorerKey, lk1.Code, Lk1.code2, lk1.UDF01 FROM dbo.WorkOrderDetail wod1 WITH(NOLOCK) 
            INNER JOIN dbo.PickDetail pkd1 WITH(NOLOCK) ON wod1.StorerKey = pkd1.StorerKey AND ISNULL(wod1.ExternWorkOrderKey, '') = pkd1.OrderKey
            INNER JOIN dbo.CODELKUP lk1 WITH(NOLOCK) ON wod1.StorerKey = lk1.StorerKey AND lk1.LISTNAME = 'LVSPRICELB' AND wod1.Type = lk1.code2
            WHERE wod1.StorerKey = @cStorerKey
               AND wod1.ExternLineNo = ''
               AND wod1.Remarks = 'PriceTicketFormat'
               AND ISNULL(pkd1.CaseID, '') = @cDropID) AS wodEX
      ON wod.StorerKey = wodEX.StorerKey AND lk.Code = wodEX.Code
   WHERE wo.StorerKey = @cStorerKey
      AND pkd.Sku = @cSKU
      AND ISNULL(pkd.CaseID, '') = @cDropID
      AND wod.ExternLineNo <> ''

   SELECT @nRowCount = COUNT(1) FROM @tLabels

   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 222256
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrint
      GOTO Quit
   END

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

      DELETE FROM @tPriceLabelList

      INSERT INTO @tPriceLabelList (Variable, Value) 
      VALUES 
         ( '@cLabelNo', @cDropID),
         ( '@cSKU', @cSKU)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinterGroup, @cPaperPrinter,
         @cLabelName, -- Report type
         @tPriceLabelList, -- Report params
         'rdt_593PriceLabel01',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @nNoOfCopy = @nQty

      IF @nErrNo <> 0
      BEGIN
         GOTO Quit
      END
   END

Quit:

GO