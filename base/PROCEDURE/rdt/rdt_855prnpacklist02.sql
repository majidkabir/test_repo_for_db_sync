SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855PrnPackList02                                */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 02-Nov-2017 1.0  James      WMS3257. Created                         */
/* 19-Nov-2018 1.1  Ung        WMS-6932 Add ID param                    */
/* 19-Mar-2019 1.2  James      WMS-8002 Add TaskDetailKey param(james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_855PrnPackList02] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cRefNo          NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),
   @cLoadKey        NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cDropID         NVARCHAR( 20),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cOption         NVARCHAR( 1),
   @cType           NVARCHAR( 10),
   @nErrNo          INT                OUTPUT, 
   @cErrMsg         NVARCHAR( 20)      OUTPUT, 
   @cPrintPackList  NVARCHAR( 1)  = '' OUTPUT, 
   @cID             NVARCHAR( 18) = '',
   @cTaskDetailKey  NVARCHAR( 10) = ''
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @cLabelPrinter  NVARCHAR( 10),
      @cPaperPrinter  NVARCHAR( 10),
      @cStorerKey     NVARCHAR( 15), 
      @cSOStatus      NVARCHAR( 10),
      @cLabelNo       NVARCHAR( 20),
      @cPickConfirmStatus       NVARCHAR( 1),
      @cSkipChkPSlipMustScanOut NVARCHAR( 1),
      @nCartonNo      INT,
      @nPPA_QTY       INT,
      @nPD_QTY        INT,
      @nLabelPrinted  INT,
      @nManifestPrinted  INT,
      @nExpectedQty   INT,
      @nPackedQty     INT

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20),
           @cErrMsg03        NVARCHAR( 20),
           @cErrMsg04        NVARCHAR( 20),
           @cErrMsg05        NVARCHAR( 20),
           @cErrMsg06        NVARCHAR( 20),
           @cErrMsg07        NVARCHAR( 20),
           @cErrMsg08        NVARCHAR( 20),
           @cErrMsg09        NVARCHAR( 20),
           @cErrMsg10        NVARCHAR( 20),
           @cErrMsg11        NVARCHAR( 20),
           @cErrMsg12        NVARCHAR( 20),
           @cErrMsg13        NVARCHAR( 20),
           @cErrMsg14        NVARCHAR( 20),
           @cErrMsg15        NVARCHAR( 20)

   SET @cErrMsg01 = ''
   SET @cErrMsg02 = ''
   SET @cErrMsg03 = ''
   SET @cErrMsg04 = ''
   SET @cErrMsg05 = '' 
   SET @cErrMsg06 = ''
   SET @cErrMsg07 = ''
   SET @cErrMsg08 = ''
   SET @cErrMsg09 = ''
   SET @cErrMsg10 = ''
   SET @cErrMsg11 = ''
   SET @cErrMsg12 = ''
   SET @cErrMsg13 = ''
   SET @cErrMsg14 = ''
   SET @cErrMsg15 = ''

   -- Get printer
   SELECT @cLabelPrinter = Printer, 
          @cPaperPrinter = Printer_Paper, 
          @cStorerKey = StorerKey
   FROM RDT.RDTMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)
   -- Check scan-out, PickDetail.Status must = 5
   IF @cSkipChkPSlipMustScanOut = '0'
      SET @cPickConfirmStatus = '5'

   IF @nStep = 2
   BEGIN
      -- Get PPA QTY
      SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID

      -- Get Pickdetail QTY
      SELECT @nPD_QTY = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE DropID = @cDropID
      AND   StorerKey = @cStorerKey
      AND   [Status] >= @cPickConfirmStatus
      AND   [Status] < '9'

      IF @nPPA_QTY = @nPD_QTY
      BEGIN
         SET @cType = 'PRINT'

         SELECT TOP 1 @cOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   StorerKey = @cStorerKey
         AND   [Status] >= @cPickConfirmStatus
         AND   [Status] < '9'

         SELECT @cLoadKey = LoadKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL( SUM( PD.Qty), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.Storerkey = @cStorerkey
         AND   PD.Status >= @cPickConfirmStatus
         AND   PD.Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL( SUM( PD.Qty), 0) 
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         WHERE PH.LoadKey = @cLoadKey
         AND   PH.Storerkey = @cStorerkey

         IF @nExpectedQty <> @nPackedQty
            SET @cPrintPackList = '0' -- No
         ELSE
            SET @cPrintPackList = '1' -- Yes
      END

      -- Print pack list
      IF @cType = 'PRINT'
      BEGIN
         SET @nLabelPrinted = 0
         SET @nManifestPrinted = 0

         SELECT TOP 1 @cStorerKey = StorerKey,
                      @cPickSlipNo = PickSlipNo,
                      @nCartonNo = CartonNo, 
                      @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID 

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 116551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Ctn Found
            GOTO Quit
         END

         -- Get Order info
         SELECT @cSOStatus = O.SOStatus
         FROM dbo.Orders O WITH (NOLOCK) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE PD.PickSlipNo = @cPickSlipNo
      
         -- Order cancel not print packing list
         IF @cSOStatus = 'CANC'
         BEGIN
            SET @nErrNo = 116552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Cancel
            SET @cPrintPackList = '0' -- No
            GOTO Quit
         END

         -- Common params
         DECLARE @tSHIPPLABEL AS VariableTable
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonEnd', @nCartonNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLabelNoStart', @cLabelNo)
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLabelNoEnd', @cLabelNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
            'SHIPPLABEL', -- Report type
            @tSHIPPLABEL, -- Report params
            'rdt_855PrnPackList02', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         ---- Update DropID
         --UPDATE dbo.DropID SET
         --   LabelPrinted = '1'
         --WHERE DropID = @cDropID

         --IF @@ERROR <> 0
         --BEGIN
         --   SET @nErrNo = 116553
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
         --   GOTO Fail
         --END
         --ELSE
         --BEGIN
         --   SET @nLabelPrinted = 1
         --   SET @cErrMsg01 = rdt.rdtgetmessage( 116555, @cLangCode, 'DSP')
         --END

         -- Common params
         DECLARE @tCARTONLBL AS VariableTable
         INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
         INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
         INSERT INTO @tCARTONLBL (Variable, Value) VALUES ( '@nCartonEnd', @nCartonNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
            'CARTONLBL', -- Report type
            @tCARTONLBL, -- Report params
            'rdt_855PrnPackList02', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
                  
         -- Update DropID
         UPDATE dbo.DropID SET
            ManifestPrinted = '1'
         WHERE DropID = @cDropID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 116553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
            GOTO Fail
         END
         ELSE
         BEGIN
            SET @nManifestPrinted = 1
            SET @cErrMsg01 = rdt.rdtgetmessage( 116554, @cLangCode, 'DSP')
            SET @cErrMsg02 = rdt.rdtgetmessage( 116555, @cLangCode, 'DSP')
         END

         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01, @cErrMsg02

         IF @nErrNo = '1'
         BEGIN
            SET @cErrMsg01 = ''
            set @cErrMsg02 = ''
            SET @nErrNo = 0
         END
      END

   END   -- @nStep = 2

   IF @nStep = 5
   BEGIN
      IF @cOption = '1' -- Option 1 only need printing
      BEGIN
         SELECT TOP 1 @cOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE DropID = @cDropID
         AND   StorerKey = @cStorerKey
         AND   [Status] >= @cPickConfirmStatus
         AND   [Status] < '9'

         SELECT @cLoadKey = LoadKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL( SUM( PD.Qty), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.Storerkey = @cStorerkey
         AND   PD.Status >= @cPickConfirmStatus
         AND   PD.Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL( SUM( PD.Qty), 0) 
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         WHERE PH.LoadKey = @cLoadKey
         AND   PH.Storerkey = @cStorerkey

         IF @nExpectedQty <> @nPackedQty
         BEGIN
            SET @nErrNo = 116556
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Last Carton
            GOTO Fail
         END
         ELSE
         BEGIN
            SELECT @cPickSlipNo = PickSlipNo
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey

            -- Common params
            DECLARE @tPackingList AS VariableTable
            INSERT INTO @tPackingList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter, 
               'PACKLIST', -- Report type
               @tPackingList, -- Report params
               'rdt_855PrnPackList02', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
                  
            -- Update DropID
            UPDATE dbo.DropID SET
               ManifestPrinted = '1'
            WHERE DropID = @cDropID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 116557
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
               GOTO Fail
            END
            ELSE
            BEGIN
               SET @nManifestPrinted = 1
               SET @cErrMsg01 = rdt.rdtgetmessage( 116558, @cLangCode, 'DSP')
            END

            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01

            IF @nErrNo = '1'
            BEGIN
               SET @cErrMsg01 = ''
               SET @nErrNo = 0
            END
         END
      END   -- @cOption = 1
   END      -- @nStep = 5
                  
Fail:  
   RETURN  
Quit:  
   SET @nErrNo = 0 -- Not stopping error           


GO