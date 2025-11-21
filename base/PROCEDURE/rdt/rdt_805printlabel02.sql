SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805PrintLabel02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 04-05-2017 1.0  ChewKP      WMS-1841 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_805PrintLabel02] (
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
          
   SET @cDataWindow = ''
   SET @cTargetDB   = ''
   SET @nErrNo      = 0 

   SELECT 
      @cLabelPrinter = Printer
      --@cUserName = UserName
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
   FROM rdt.rdtReport WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND   ReportType = 'CARTONLBL'   
      
   SELECT @cPickSlipNo = PickSlipNo 
         ,@nCartonNo   = CartonNo 
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE LabelNo = @cCartonID 
   
   IF ISNULL(@cPickSlipNo,'' ) = '' 
   BEGIN
      GOTO QUIT 
   END
   
   EXEC RDT.rdt_BuiltPrintJob      
        @nMobile,      
        @cStorerKey,      
        'CARTONLBL',      -- ReportType      
        'CartonLabel',    -- PrintJobName      
        @cDataWindow,      
        @cLabelPrinter,      
        @cTargetDB,      
        @cLangCode,      
        @nErrNo  OUTPUT,      
        @cErrMsg OUTPUT,    
        @cPickSlipNo, 
        @nCartonNo,
        @nCartonNo 

Quit:
END

GO