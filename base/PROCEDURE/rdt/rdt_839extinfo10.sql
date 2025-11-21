SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_839ExtInfo10                                    */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-03-07 1.0  yeekung    WMS-19062 Created                         */  
/* 2022-05-07 1.1  Yeekung    WMS-20134 fix pickzone nvarchar 1->10     */
/*                            (yeekung01)                               */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839ExtInfo10] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,       
   @nAfterStep   INT,    
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), --(yeekung01)  
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @nActQty      INT,
   @nSuggQTY     INT,
   @cExtendedInfo NVARCHAR(20) OUTPUT, 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
   DECLARE @ccurPD      CURSOR
   DECLARE @nPD_Qty     INT
   DECLARE @cOrderkey   NVARCHAR(20)
   
   SET @cExtendedInfo = ''

   IF @nStep IN (1,2) 
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cOrderkey=orderkey
         FROM Pickheader (NOLOCK)
         WHERE pickheaderkey=@cPickSlipNo

         SELECT @cExtendedInfo=notes
         FROM  orders (nolock)
         where orderkey=@cOrderkey
      END
   END
  
QUIT:  
 

GO