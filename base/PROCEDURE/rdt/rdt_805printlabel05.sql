SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805PrintLabel05                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 20-03-2021 1.0  yeekung     WMS-16300 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_805PrintLabel05] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 15) 
   ,@cStation1    NVARCHAR( 10)
   ,@cStation2    NVARCHAR( 10)
   ,@cStation3    NVARCHAR( 10)
   ,@cStation4    NVARCHAR( 10)
   ,@cStation5    NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1)
   ,@cCartonID    NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPickSlipNo NVARCHAR(20) 
          ,@nCartonNo   INT 
   
   DECLARE @cLabelPrinter NVARCHAR( 10)

   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cDataWindow   NVARCHAR( 50)  
   DECLARE @cShipLabel    NVARCHAR( 20) 
   DECLARE @cNewCarton    NVARCHAR( 20)   
   DECLARE @cLoadkey      NVARCHAR( 20)
   DECLARE @cOrderkey     NVARCHAR( 20)     
          
   SET @cDataWindow = ''
   SET @cTargetDB   = ''
   SET @nErrNo      = 0 

   DECLARE @tRDTUCCLabel AS VariableTable 
   DECLARE @tRDTPrintJob AS VariableTable
   
   SELECT @cDataWindow = DataWindow,     
          @cTargetDB = TargetDB     
   FROM rdt.rdtReport WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND   ReportType = @cShipLabel   
      
   SELECT @cOrderkey=OrderKey,
          @cLoadkey=loadkey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE cartonid = @cCartonID 
   AND Station IN (@cStation1,@cStation2,@cStation3,@cStation4,@cStation5)

   IF @cOrderkey<>''
      SELECT @cPickSlipNo=pickheaderkey
      FROM pickheader (NOLOCK)
      WHERE orderkey=@cOrderkey
   ELSE IF @cLoadkey<>''
      SELECT @cPickSlipNo=pickheaderkey
      FROM pickheader (NOLOCK)
      WHERE ExternOrderKey=@cloadkey

   SELECT @nCartonNo=CartonNo
   FROM packdetail (NOLOCK)
   WHERE pickslipno=@cPickSlipNo

   SELECT @cLabelPrinter=Printer
   FROM rdt.rdtmobrec (NOLOCK)
   WHERE mobile=@nMobile


   INSERT INTO @tRDTPrintJob (Variable, Value) VALUES   
         ( '@cPickSlipNo',          @cPickslipno),   
         ( '@nCartonNo',            CAST(@nCartonNo AS NVARCHAR(5)))

   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',  
      'cartonlbl',      -- Report type  
      @tRDTPrintJob,    -- Report params  
      'rdt_PTLStation_Confirm',   
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT

   IF @nErrNo<>0
      GOTO QUIT

    INSERT INTO @tRDTUCCLabel (Variable, Value) VALUES  
      ( '@cstorerkey',          @cStorerKey),   
      ( '@cPickslipno',          @cPickslipno),   
      ( '@nCartonNo',            CAST(@nCartonNo AS NVARCHAR(5)))

   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',  
      'ucclabel',      -- Report type  
      @tRDTUCCLabel,    -- Report params  
      'rdt_PTLStation_Confirm',   
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT

   IF @nErrNo<>0
      GOTO QUIT

Quit:
END

GO