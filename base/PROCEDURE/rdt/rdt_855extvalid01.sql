SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_855ExtValid01                                   */  
/* Purpose: Check if user login with printer                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2017-11-21 1.0  James     WMS3257. Created                           */  
/* 2018-11-19 1.1  Ung       WMS-6932 Add ID param                      */
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james01) */
/* 2019-04-22 1.3  James     WMS-7983 Add VariableTable (james02)       */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_855ExtValid01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFacility   NVARCHAR(5),
   @cRefNo      NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cLoadKey    NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cID         NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  

   DECLARE @nInputKey      INT,
           @cLabelPrinter  NVARCHAR( 10),
           @cPaperPrinter  NVARCHAR( 10),
           @cDataWindow    NVARCHAR( 50),
           @cTargetDB      NVARCHAR( 20)  
           
   SELECT @cLabelPrinter = Printer, 
          @cPaperPrinter = Printer_Paper,
          @nInputKey = InputKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1  
      BEGIN  
         -- If setup rdtreport only check
         IF EXISTS ( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   ReportType IN ('CARTONLBL', 'SHIPPLABEL')
            AND  (Facility = @cFacility OR Facility = '')
            AND  (Function_ID = @nFunc OR Function_ID = 0))
         BEGIN
            IF ISNULL( @cLabelPrinter, '') = ''
            BEGIN
               SET @nErrNo = 117001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq 
               GOTO Quit
            END            
         END   -- ReportType IN ('CARTONLBL', 'SHIPPLABEL')

         -- If setup rdtreport only check
         IF EXISTS ( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   ReportType = 'PACKLIST'
            AND  (Facility = @cFacility OR Facility = '')
            AND  (Function_ID = @nFunc OR Function_ID = 0))
         BEGIN
            IF ISNULL( @cPaperPrinter, '') = ''
            BEGIN
               SET @nErrNo = 117002
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq 
               GOTO Quit
            END            
         END   -- ReportType = 'PACKLIST'
      END      -- @nStep = 1
   END         -- @nInputKey = 1
  
QUIT:  
 

GO