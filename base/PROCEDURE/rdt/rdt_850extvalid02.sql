SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_850ExtValid02                                   */  
/* Purpose: Check if user login with printer                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author    Purposes                                   */  
/* 2023-02-16 1.0  yeekung   WMS-21562 Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_850ExtValid02] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFacility   NVARCHAR(5),
   @cRefNo      NVARCHAR( 20),
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
         IF @cRefNo=''
         BEGIN
            SET @nErrNo = 196601 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Ref#
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO QUIT
         END

         IF @cLoadkey=''
         BEGIN
            SET @nErrNo = 196602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Ref#
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO QUIT
         END
         
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
               FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               JOIN Orders O (NOLOCK) ON LP.loadkey=O.loadkey 
               JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey=PD.orderkey 
            WHERE O.trackingno = @cRefNo
               AND PD.storerkey = @cStorerKey
               AND LP.loadkey=@cloadkey) -- 9=Closed
         BEGIN
            SET @nErrNo = 196603 
            SET @cErrMsg = @cRefNo--rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidRefNo
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO QUIT
         END
      END
   END 
   ELSE IF @nInputKey = 0
   BEGIN
      IF @nStep = 3
      BEGIN  
         DECLARE @cErrMsg1 NVARCHAR(20)
         DECLARE @cErrMsg2 NVARCHAR(20)

         SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 98110, @cLangCode, 'DSP'), 7, 14) --Stage loc
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 98111, @cLangCode, 'DSP'), 7, 14) --Not match
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END     
      END
   END   
  
QUIT:  
 

GO