SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Store procedure: rdt_855PrnPackList05                                */
/* Copyright: Maersk WMS                                                */
/*                                                                      */
/* Purpose: Print dispatch label criteria                               */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-06-21 1.0  NLT013     FCR-386. Created                          */
/************************************************************************/
  
CREATE   PROC rdt.rdt_855PrnPackList05 (  
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
   @cID             NVARCHAR( 18) = '' ,
   @cTaskDetailKey  NVARCHAR( 10) = ''
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cStorerKey    NVARCHAR( 15)
   DECLARE @cPPAPromptDiscrepancy NVARCHAR( 1)
   DECLARE @cFacility NVARCHAR(20)
   
   IF @nFunc = 855
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 0
         BEGIN
            IF @cType ='CHECK'
            BEGIN
               SET @cPrintPackList = '1'
            END 
         END
      END
   END

Fail:
   RETURN
Quit:
   SET @nErrNo = 0 -- Not stopping error 


GO