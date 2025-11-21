SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805PrintLabel06                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 20-03-2021 1.0  yeekung     WMS-16833 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_805PrintLabel06] (
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
          ,@cwavekey    NVARCHAR(20)
   
   DECLARE @cLabelPrinter NVARCHAR( 10)

   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cDataWindow   NVARCHAR( 50)  
   DECLARE @cShipLabel    NVARCHAR( 20) 
   DECLARE @cNewCarton    NVARCHAR( 20)   
   DECLARE @cLoadkey      NVARCHAR( 20)
   DECLARE @cOrderkey     NVARCHAR( 20)    
   DECLARE @clabelno      NVARCHAR( 20) 
   DECLARE @cPaperPrinter NVARCHAR( 20)
          
   SET @cDataWindow = ''
   SET @cTargetDB   = ''
   SET @nErrNo      = 0 

   DECLARE @tRDTUCCLabel AS VariableTable 
   DECLARE @tRDTPrintJob AS VariableTable 
   DECLARE @tRDTPVHlBL AS VariableTable
   
   SELECT @cDataWindow = DataWindow,     
          @cTargetDB = TargetDB     
   FROM rdt.rdtReport WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND   ReportType = @cShipLabel   
      
   SELECT @cwavekey=wavekey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE cartonid = @cCartonID 
   AND Station IN (@cStation1,@cStation2,@cStation3,@cStation4,@cStation5)

   DECLARE @curPTL CURSOR 

   SELECT @cLabelPrinter=Printer,
          @cPaperPrinter=Printer_Paper
   FROM rdt.rdtmobrec (NOLOCK)
   WHERE mobile=@nMobile


   SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT pd.CaseID,pd.DropID,pd.PickSlipNo
   FROM wave WD WITH (NOLOCK)   
      JOIN Orders O WITH (NOLOCK) ON (WD.WaveKey = O.UserDefine09)   
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
   WHERE wd.wavekey=@cwavekey
      AND PD.DropID = @cCartonID   
      --AND PD.SKU = '036182922762'  
      AND PD.Status <= '5'  
      AND PD.CaseID <> ''  
      AND PD.QTY > 0  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'
   GROUP BY pd.CaseID,pd.DropID,pd.PickSlipNo

   OPEN @curPTL    
   FETCH NEXT FROM @curPTL INTO @clabelno, @cCartonID,@cPickslipno    
   WHILE @@FETCH_STATUS = 0    
   BEGIN 

      SELECT @nCartonNo=CartonNo
      FROM dbo.PackDetail (NOLOCK)
      WHERE PickSlipNo=@cPickSlipNo


      INSERT INTO @tRDTPrintJob (Variable, Value) VALUES   
            ( '@cPickSlipNo',          @cPickslipno),   
            ( '@nCartonNo',            CAST(@nCartonNo AS NVARCHAR(5)))

      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,  
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
         ( '@cLabelNo',            @clabelno )

      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,  
         'ucclabel',      -- Report type  
         @tRDTUCCLabel,    -- Report params  
         'rdt_PTLStation_Confirm',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT

      IF @nErrNo<>0
         GOTO QUIT

      INSERT INTO @tRDTPVHlBL (Variable, Value) VALUES  
      ( '@cStorerKey',          @cStorerKey),   
      ( '@clabelno',            @clabelno)

      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,  
         'PVHLBL1',      -- Report type  
         @tRDTPVHlBL,    -- Report params  
         'rdt_PTLStation_Confirm',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT

      FETCH NEXT FROM @curPTL INTO @clabelno, @cCartonID,@cPickslipno 
   END

IF @nErrNo<>0
   GOTO QUIT

Quit:
END

GO