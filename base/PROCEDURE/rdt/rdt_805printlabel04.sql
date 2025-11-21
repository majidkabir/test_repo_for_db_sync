SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805PrintLabel04                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 25-09-2020 1.0 YeeKung     WMS-14910 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_805PrintLabel04] (
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
   
   DECLARE @cPickSlipNo NVARCHAR(10) 
          ,@nCartonNo   INT 
   
   DECLARE @cLabelPrinter NVARCHAR( 10)

   DECLARE @cTargetDB     NVARCHAR( 20)    
   DECLARE @cDataWindow   NVARCHAR( 50)  
   DECLARE @cShipLabel    NVARCHAR( 20) 
   DECLARE @cNewCarton    NVARCHAR( 20)         
          
   SET @cDataWindow = ''
   SET @cTargetDB   = ''
   SET @nErrNo      = 0 

   SET @cShipLabel='SHIPPLBLLV'
   
   SELECT @cDataWindow = DataWindow,     
          @cTargetDB = TargetDB     
   FROM rdt.rdtReport WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND   ReportType = @cShipLabel   
      
   SELECT @cPickSlipNo = PickSlipNo, 
          @nCartonNo   = cartonno
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE labelno = @cCartonID 

   SELECT @cNewCarton = O_Field01
   from rdt.rdtmobrec (NOLOCK)
   where mobile=@nMobile

   SELECT @clabelprinter=long
   from codelkup cd (nolock)
   join rdt.rdtptlstationlog PTL (NOLOCK)
   ON cd.storerkey=PTL.storerkey and cd.udf01=ptl.station
   join deviceprofile dp (NOLOCK) 
   ON dp.deviceid=ptl.station and cd.udf02=dp.row and dp.DevicePosition=ptl.position
   where ptl.station in(@cStation1,@cStation2,@cStation3,@cStation4,@cStation5)
   and ptl.storerkey=@cstorerkey
   and ptl.cartonid in(@cCartonID,@cNewCarton)
   and code2='805'
   and listname='PTLPrinter'
   
   DECLARE @tPalletLabel AS VariableTable 

   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cpickslipno',  @cpickslipno)  
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cFirstCartonno',  @ncartonNO) 
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cLastCartonno',  @ncartonNO)  
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cparam1',  'S')  

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @clabelprinter, '', 
      @cShipLabel, -- Report type
      @tPalletLabel, -- Report params
      'rdt_805PrintLabel04', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo<>0
      GOTO QUIT

   DELETE FROM @tPalletLabel

   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cpickslipno',  @cpickslipno)  
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cFirstCartonno',  @ncartonNO) 
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cLastCartonno',  @ncartonNO)  
   INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cparam1',  'C')  

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @clabelprinter, '', 
      @cShipLabel, -- Report type
      @tPalletLabel, -- Report params
      'rdt_805PrintLabel04', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

   IF @nErrNo<>0
      GOTO QUIT

Quit:
END

GO