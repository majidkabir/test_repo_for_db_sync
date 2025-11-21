SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtUpd12                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 31-08-2021 1.0  yeekung    WMS-17656 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtUpd12] (
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

   DECLARE @cLabelLine NVARCHAR(5)
   DECLARE @nTranCount INT
   DECLARE @cPackDetailCartonID  NVARCHAR( 20),
           @cOrderkey  NVARCHAR(20),
           @cuserdefine04 NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 838 -- Pack
   BEGIN

      IF @nStep = 4-- Weight,Cube
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @c_OrderKey NVARCHAR(20),
                    @nPDQTY INT,
                    @nPackQty INT

            SELECT @c_OrderKey=OrderKey
            FROM pickheader PH  WITH (NOLOCK) 
            WHERE PH.PickHeaderKey=@cPickSlipNo

            SELECT @nPDQTY=SUM(Qty)
            FROM pickdetail (NOLOCK) 
            WHERE orderkey=@c_OrderKey

            SELECT @nPackQty=SUM(Qty)
            FROM packheader PH (NOLOCK) JOIN
            packdetail PD ON PH.PickSlipNo=PD.PickSlipNo
            WHERE ph.PickSlipNo=@cPickSlipNo
            AND PH.storerkey=@cStorerKey

            IF @nPackQty=@nPDQTY
            BEGIN
               DECLARE  @cLabelPrinter NVARCHAR(20),
                        @cPaperPrinter NVARCHAR(20)

               SELECT @cLabelPrinter=Printer,
               @cPaperPrinter=Printer_Paper
               FROM rdt.RDTMOBREC (nolock)
               WHERE mobile=@nMobile

               -- Common params  
               DECLARE @tShipLabel AS VariableTable  
               INSERT INTO @tShipLabel (Variable, Value) VALUES   
                  ( '@cStorerKey',     @cStorerKey),   
                  ( '@cPickSlipNo',    @cPickSlipNo),   
                  ( '@cFromDropID',    @cFromDropID),   
                  ( '@cPackDtlDropID', @cPackDtlDropID),   
                  ( '@cLabelNo',       @cLabelNo),   
                  ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                  'SHIPCLABEL', -- Report type  
                  @tShipLabel, -- Report params  
                  'rdt_838ExtUpd12',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
               IF @nErrNo <> 0  
                  GOTO Quit  

               IF EXISTS (SELECT 1 FROM orders (NOLOCK) WHERE orderkey=@c_OrderKey AND DocType='N')
               BEGIN
                  -- Get report param  
                  DECLARE @tPackList AS VariableTable  
                  INSERT INTO @tPackList (Variable, Value) VALUES   
                     ( '@cPickSlipNo',    @cPickSlipNo),   
                     ( '@cFromDropID',    @cFromDropID),   
                     ( '@cPackDtlDropID', @cPackDtlDropID)  
  
                  -- Print packing list  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
                     'PACKLIST', -- Report type  
                     @tPackList, -- Report params  
                     'rdtfnc_Pack',   
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT  
                  IF @nErrNo <> 0  
                     GOTO Quit  

               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838ExtUpd12 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO