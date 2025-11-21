SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_805DecodeIDSP05                                       */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2021-03-01 1.0  James    WMS-15658. Created                                */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_805DecodeIDSP05] (  
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cScanID      NVARCHAR( 20)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT,
   @nDefaultSKU  INT  OUTPUT,
   @nDefaultQty  INT  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nFunc = 805 -- PTLStation
   BEGIN
      SELECT TOP 1 @cSKU = SKU
      FROM dbo.PickDetail WITH (NOLOCK)   
      WHERE Storerkey = @cStorerKey
      AND   [Status] IN ( '0', '3', '5')
      AND   [Status] <> '4'  
      AND   QTY > 0  
      AND   DropID = @cScanID
      ORDER BY 1
      
      SET @nDefaultSKU = 1
   END
   
END  
  
Quit:  
  

GO