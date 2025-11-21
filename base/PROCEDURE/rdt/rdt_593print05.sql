SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_593Print05                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2016-03-18 1.0  ChewKP   SOS#365758 Created                             */
/* 2016-09-06 1.1  ChewKP   SOS#375735 Carton Label Report (ChewKP01)      */
/* 2017-11-30 1.2  ChewKP   WMS-3525 - UCC Input as Optional (ChewKP02)    */
/* 2017-12-15 1.3  ChewKP   WMS-3643 - Add New Option (ChewKP03)           */
/* 2018-04-20 1.4  SPChin   INC0197653 - Cater One UCCNo with Multi And    */
/*                                       Single SKU                        */
/* 2018-08-13 1.4  Ung      WMS-5967 Add L02 check for RETURNNOTE          */
/* 2018-09-05 1.5  LZG      INC0374541 - Added StorerKey (ZG01)            */
/* 2019-03-20 1.6  Leong    INC0629895 - Add Max NoOfCopy.                 */
/* 2019-08-06 1.7  SPChin   INC0801347 - Add ReceiptKey Check              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print05] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- OrderKey
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success     INT

   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cFacility     NVARCHAR(  5)
   DECLARE @cLabelType    NVARCHAR( 20)
         , @cExternOrderKey     NVARCHAR(20)
         , @cOrderKey     NVARCHAR(10)
         , @cPickSlipNo   NVARCHAR(10)
         , @nCartonNo     INT
         , @cUCC          NVARCHAR(20)
         , @cSKU          NVARCHAR(20)
         , @nSKUCnt       INT
         , @cLabelNo      NVARCHAR(20)
         , @cLoadKey      NVARCHAR(10)
         , @cWaveKey      NVARCHAR(10)
         --, @cExternOrderKey NVARCHAR(30)
         , @cDeliveryDate NVARCHAR(18)
         , @nMaxCartonNo  INT
         , @cID           NVARCHAR(18)
         , @cReceiptKey   NVARCHAR(10)
         , @cQty          NVARCHAR(5)
         , @nQty          INT -- INC0629895
         , @nMaxNoOfCopy  INT -- INC0629895

   DECLARE @tOutBoundList AS VariableTable

   SELECT @cLabelPrinter = Printer
         ,@cPaperPrinter = Printer_Paper
         ,@cUserName     = UserName
         ,@cFacility     = Facility
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 97801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END


   IF @cOption = '1'
   BEGIN

      SET @cUCC = ISNULL(@cParam1,'')
      SET @cSKU = ISNULL(@cParam3,'')
      SET @cQty = ISNULL(@cParam5,'')

      IF ISNULL(@cUCC,'' ) = '' AND ISNULL(@cSKU,'') = '' -- (ChewKP02)
      BEGIN
         SET @nErrNo = 97811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --EitherInputReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO Quit
      END

      IF @cUCC <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND UCCNo = @cUCC )
         BEGIN
            SET @nErrNo = 97803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCCNotFound
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
            GOTO Quit
         END

         --SELECT @cQty = Qty          --INC0197653
         --FROM dbo.UCC WITH (NOLOCK)
         --WHERE StorerKey = @cStorerKey
         --AND UCCNo = @cUCC

      END

      IF ISNULL(@cSKU,'' )  <> ''
      BEGIN
         -- Get SKU barcode count
         --DECLARE @nSKUCnt INT
         EXEC rdt.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 97804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
            GOTO Quit
         END

         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 97805
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
            GOTO Quit
         END

         -- Get SKU code
         EXEC rdt.rdt_GETSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         IF ISNULL(@cSKU,'') = ''
         BEGIN
            SET @nErrNo = 97806
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidSKU
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
            GOTO Quit
         END

--         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
--                         WHERE StorerKey = @cStorerKey
--                         AND UCCNo = @cUCC
--                         AND SKU = @cSKU )
--         BEGIN
--            SET @nErrNo = 97807
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUNotInUCC
--            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
--            GOTO Quit
--         END
      END

      IF ISNULL(@cQty,'') = ''
      BEGIN
         SET @cQty = 1
      END

      -- INC0629895 (Start)
      SELECT @nQty = CASE WHEN rdt.rdtIsValidQTY(@cQty, 1) = 1 THEN @cQty ELSE 0 END

      SET @nMaxNoOfCopy = 0
      SELECT @nMaxNoOfCopy = ISNULL(Short, '0')
      FROM dbo.CodeLkUp WITH (NOLOCK)
      WHERE ListName = 'MaxNoCopy'
      AND Code = 'NoOfCopy'
      AND StorerKey = @cStorerKey

      IF ISNULL(@nQty, 0) > ISNULL(@nMaxNoOfCopy, 0) AND ISNULL(RTRIM(@cUCC),'') = ''
      BEGIN
         SET @nErrNo = 97816
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoOfCopyExceed
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO QUIT
      END
      -- INC0629895 (End)

      --INC0197653 Start
      IF ISNULL(@cSKU,'' ) <> ''
      BEGIN
         IF ISNULL(@cUCC,'' ) <> ''
         BEGIN
            SELECT @cQty = Qty
            FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND SKU = @cSKU
         END

         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cUCC', @cUCC)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKU)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cQty', @cQty)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)         -- ZG01

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
         'PRICELABEL', -- Report type
         @tOutBoundList, -- Report params
         'rdt_593Print05',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
      ELSE
      BEGIN
         DECLARE CUR_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCCNo, SKU, Qty
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
         ORDER BY SKU

         OPEN CUR_1
         FETCH NEXT FROM CUR_1 INTO @cUCC, @cSKU, @cQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cUCC', @cUCC)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKU)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cQty', @cQty)
            INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)         -- ZG01

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            'PRICELABEL',   -- Report type
            @tOutBoundList, -- Report params
            'rdt_593Print05',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            DELETE @tOutBoundList

         FETCH NEXT FROM CUR_1 INTO @cUCC, @cSKU, @cQty
         END
         CLOSE CUR_1
         DEALLOCATE CUR_1
      END
      --INC0197653 End

--         SET @cLabelType = 'PRICELABEL'
--
--         EXEC dbo.isp_BT_GenBartenderCommand
--               @cLabelPrinter
--             , @cLabelType
--             , @cUserName
--             , @cUCC
--             , @cSKU
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , @cStorerKey
--             , '1'
--             , '0'
--             , 'N'
--             , @nErrNo  OUTPUT
--             , @cERRMSG OUTPUT

--      END
--      ELSE
--      BEGIN
--
--         SET @cLabelType = 'PRICELABEL'
--
--         EXEC dbo.isp_BT_GenBartenderCommand
--               @cLabelPrinter
--             , @cLabelType
--             , @cUserName
--             , @cUCC
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , ''
--             , @cStorerKey
--             , '1'
--             , '0'
--             , 'N'
--             , @nErrNo  OUTPUT
--             , @cERRMSG OUTPUT
--
--
--      END
   END

   -- (ChewKP01)
   IF @cOption = '2'
   BEGIN
      SET @cLabelNo = @cParam1

      -- Check blank
      IF ISNULL(RTRIM(@cLabelNo), '') = ''
      BEGIN
         SET @nErrNo = 97808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO QUIT
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND LabelNo = @cLabelNo )
      BEGIN
         SET @nErrNo = 97809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO QUIT
      END

      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      SET @cPickSlipNo = ''

      SELECT @cDataWindow = DataWindow,
             @cTargetDB = TargetDB
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = 'SHIPPLBLVF'

      SELECT @cPickSlipNo = PickSlipNo
            ,@nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo

      SELECT @nMaxCartonNo = MAX(CartonNo )
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo

      EXEC RDT.rdt_BuiltPrintJob
          @nMobile,
          @cStorerKey,
          'SHIPPLBLVF',    -- ReportType
          'SHIPPLBLVF',    -- PrintJobName
          @cDataWindow,
          @cLabelPrinter,
          @cTargetDB,
          @cLangCode,
          @nErrNo  OUTPUT,
          @cErrMsg OUTPUT,
          @cLabelNo,
          @cStorerKey

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO QUIT
      END

--      -- To Indicate Label Printed
--      UPDATE dbo.PackDetail WITH (ROWLOCK)
--         SET RefNo = '1'
--      WHERE PickSlipNo = @cPickSlipNo
--      AND LabelNo = @cLabelNo
--
--      IF @@ERROR <> 0
--      BEGIN
--         SET @nErrNo = 97810
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdPackDetFail
--         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
--         GOTO QUIT
--      END

      --INSERT INTO TRACEINFO (TRACENAME , TimeIN , Col1, col2 )
      --VALUES ( 'rdt_593Print05' , Getdate() , @cStorerKey , @cPickSlipNo )

      -- If All Label Printed , Print Packing List
      IF @nMaxCartonNo = @nCartonNo
      BEGIN
         SELECT @cDataWindow = DataWindow,
             @cTargetDB = TargetDB
         FROM rdt.rdtReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'PACKLIST'

         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND LabelNo = @cLabelNo

         SELECT @cLoadKey = LoadKey
               ,@cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         SELECT --@cDeliveryDate   = CONVERT(VARCHAR(18) , DeliveryDate, 10)
                @cExternOrderKey = ExternOrderKey
               ,@cWaveKey        = UserDefine09
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         EXEC RDT.rdt_BuiltPrintJob
             @nMobile,
             @cStorerKey,
             'PACKLIST',    -- ReportType
             'PACKLIST',    -- PrintJobName
             @cDataWindow,
             @cPaperPrinter,
             @cTargetDB,
             @cLangCode,
             @nErrNo  OUTPUT,
             @cErrMsg OUTPUT,
             @cLoadKey,
             @cWaveKey,
             --@cDeliveryDate,
             @cExternOrderKey,
             @cExternOrderKey

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO QUIT
         END
      END
   END

   -- (ChewKP03)
   IF @cOption = '3'
   BEGIN
      SET @cID = @cParam1

      -- Check Paper printer blank
      IF ISNULL(RTRIM(@cPaperPrinter),'')  = ''
      BEGIN
         SET @nErrNo = 97812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrinterReq
         GOTO Quit
      END

      -- Check blank
      IF ISNULL(RTRIM(@cID), '') = ''
      BEGIN
         SET @nErrNo = 97813
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --IDReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO QUIT
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND ID = @cID
                      AND Qty > 0  )
      BEGIN
         SET @nErrNo = 97814
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --IDNotExist
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO QUIT
      END

      -- Check ID L02 in code lookup
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LOC.Facility = @cFacility
            AND LLI.StorerKey = @cStorerKey
            AND LLI.ID = @cID
            AND lli.QTY > 0
            AND EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'ASNREASON' AND Code = LA.Lottable02 AND StorerKey = LLI.StorerKey))
      BEGIN
         SET @nErrNo = 97814
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --IDNotExist
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO QUIT
      END

      SELECT TOP 1 @cReceiptKey = ReceiptKey
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ToID = @cID
      
      --INC0801347 Start
      IF ISNULL(RTRIM(@cReceiptKey), '') = ''
      BEGIN
         SET @nErrNo = 97817
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ReceiptKeyReq
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1
         GOTO QUIT
      END
      --INC0801347 End

      --DECLARE @tOutBoundList AS VariableTable
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cID',  @cID)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
         'RETURNNOTE', -- Report type
         @tOutBoundList, -- Report params
         'rdt_593Print05',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

   END

Quit:

GO