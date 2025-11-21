SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_850ExtValid01                                   */  
/* Purpose: Check if user login with printer                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2016-07-29 1.0  James     SOS366903 Created                          */  
/* 2018-11-19 1.1  Ung       WMS-6932 Add ID param                      */
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james01) */
/* 2019-04-22 1.3  James     WMS-7983 Add VariableTable (james02)       */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_850ExtValid01] (  
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
           @cPrinter_Paper NVARCHAR( 10),
           @cDataWindow    NVARCHAR( 50),
           @cTargetDB      NVARCHAR( 20)  
           
   SELECT @nInputKey = InputKey, 
          @cPrinter_Paper = Printer_Paper
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1  
      BEGIN  
         SELECT   
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReportType = 'PPADISCRPT'  

         -- If setup rdtreport only check
         IF @@ROWCOUNT > 0
         BEGIN
            -- Check data window
            IF ISNULL( @cDataWindow, '') = ''
            BEGIN
               SET @nErrNo = 102701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
               GOTO Quit
            END

            -- Check database
            IF ISNULL( @cTargetDB, '') = ''
            BEGIN
               SET @nErrNo = 102702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
               GOTO Quit
            END

            IF ISNULL( @cPrinter_Paper, '') = ''
            BEGIN
               SET @nErrNo = 102703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq 
               GOTO Quit
            END            
         END   -- @@ROWCOUNT
      END      -- @nStep = 1
   END         -- @nInputKey = 1
  
QUIT:  
 

GO