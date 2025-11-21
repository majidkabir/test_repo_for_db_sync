SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_805ExtValidSP02                                 */  
/* Purpose: Validate must have device id value                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-05-13 1.0  James      WMS-15658. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_805ExtValidSP02] (  
  @nMobile    INT,           
  @nFunc      INT,           
  @cLangCode  NVARCHAR( 3),  
  @nStep      INT,           
  @nInputKey  INT,           
  @cFacility  NVARCHAR( 5),  
  @cStorerKey NVARCHAR( 15), 
  @cStation   NVARCHAR( 10), 
  @cStation1  NVARCHAR( 10), 
  @cStation2  NVARCHAR( 10), 
  @cStation3  NVARCHAR( 10), 
  @cStation4  NVARCHAR( 10), 
  @cStation5  NVARCHAR( 10), 
  @cLight     NVARCHAR( 1),   
  @nErrNo     INT            OUTPUT,
  @cErrMsg    NVARCHAR( 20)  OUTPUT 
)  
AS  
  
SET NOCOUNT ON       
SET QUOTED_IDENTIFIER OFF       
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF   

  
   DECLARE @cDeviceID     NVARCHAR( 20)
   DECLARE @bSuccess      INT
   
   SET @nErrNo = 0 
   SET @cErrMSG = ''

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Get storer config
         DECLARE @cBypassTCPSocket NVARCHAR(1)
         SET @cBypassTCPSocket = ''
         EXECUTE nspGetRight
            NULL,
            @cStorerKey,
            NULL,
            'BypassTCPSocketClient',
            @bSuccess         OUTPUT,
            @cBypassTCPSocket OUTPUT,
            @nErrNo           OUTPUT,
            @cErrMsg          OUTPUT
      
         SELECT @cDeviceID = DeviceID
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile
      
         IF @cDeviceID = '' AND @cBypassTCPSocket <> '1'
         BEGIN
            SET @nErrNo = 167801            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Device Id req    
            GOTO QUIT
         END         
      END
   END
  
QUIT:  

 

GO