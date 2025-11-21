SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_805ExtValidSP01                                 */  
/* Purpose: Validate Weight Cube                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-07-20 1.2  ChewKP     SOS#372370 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_805ExtValidSP01] (  
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

  
IF @nFunc = 805  
BEGIN  
   
   DECLARE @nTotalStation INT
         , @nTotalAssignStation INT 
   
   SET @nErrNo = 0 
   SET @cErrMSG = ''
   SET @nTotalStation = 0 
   
   IF @nStep = 1
   BEGIN
         
         IF NOT EXISTS ( SELECT 1 
                         FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND Station = @cStation ) 
         BEGIN
                SET @nErrNo = 102551            
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTSNotAssign    
                GOTO QUIT         
         END
               
    
         
   END
   

   
END  
  
QUIT:  

 

GO