SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Store procedure: isp_ShipLabel04_RP                                     */      
/* Copyright      : Maersk                                                 */      
/*                                                                         */      
/* Date       Rev  Author   Purposes                                       */      
/* 2023-05-31 1.0  James    WMS-22632 Created                              */      
/***************************************************************************/      
      
CREATE   PROC [dbo].[isp_ShipLabel04_RP] (      
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
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cCodePage        NVARCHAR( 50)  OUTPUT          
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @cShipperKey NVARCHAR( 15)      
         , @cLabelNo    NVARCHAR(20)      
        
   SET @nErrNo = 0      
   SET @cErrMsg = ''      
   SET @cPrintTemplate = ''      
      
         
   SET @cLabelNo           = @cByRef1        
   
   SELECT @cShipperKey = ShipperKey
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cLabelNo
   
   SELECT @cPrintTemplate = PrintData       
   FROM dbo.CartonTrack WITH (NOLOCK)      
   WHERE LabelNo = @cLabelNo      
   AND   CarrierName = @cShipperKey
   
   SET @cPrintData = @cPrintTemplate      

   SET @cCodePage = '850'     
   
   GOTO Quit      
         
Quit:      

GO