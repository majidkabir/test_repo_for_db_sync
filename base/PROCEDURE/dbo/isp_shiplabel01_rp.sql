SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/    
/* Store procedure: isp_ShipLabel01_RP                                      */    
/* Copyright      : LF Logistics                                           */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2018-11-22 1.0  YeeKung  WMS-9218 Created                               */    
/***************************************************************************/    
    
CREATE PROC [dbo].[isp_ShipLabel01_RP] (    
   @nMobile          INT,     
   @nFunc            INT,     
   @cLangCode        NVARCHAR( 3),     
   @cStorerKey       NVARCHAR( 15),     
   @cByRef1          NVARCHAR( 20),     
   @cByRef2          NVARCHAR( 20),     
   @cByRef3          NVARCHAR( 20),     
   @cByRef4          NVARCHAR( 20),     
   @cByRef5          NVARCHAR( 20),     
   @cByRef6          NVARCHAR( 20),     
   @cByRef7          NVARCHAR( 20),     
   @cByRef8          NVARCHAR( 20),     
   @cByRef9          NVARCHAR( 20),     
   @cByRef10         NVARCHAR( 20),     
   @cPrintTemplate   NVARCHAR( MAX),     
   @cPrintData       NVARCHAR( MAX) OUTPUT,    
   @nErrNo           INT            OUTPUT,    
   @cErrMsg          NVARCHAR( 20)  OUTPUT    
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @bSuccess    INT    
   DECLARE @cUserName   NVARCHAR( 18)    
   DECLARE @cFacility   NVARCHAR( 5)    
         , @cLabelNo    NVARCHAR(20)    
      
   SET @nErrNo = 0    
   SET @cErrMsg = ''    
   SET @cPrintTemplate = ''    
    
       
   SET @cLabelNo           = @cByRef1      
  
   SELECT @cPrintTemplate = PrintData     
   FROM dbo.CartonTrack WITH (NOLOCK)    
   WHERE LabelNo = @cLabelNo    
       
   SET @cPrintData = @cPrintTemplate    
         
   GOTO Quit    
       
Quit:    

GO