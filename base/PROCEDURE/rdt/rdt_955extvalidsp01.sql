SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_955ExtValidsp01                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Decode dropid                                               */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 17-08-2021  1.0  yeekung     WMS17674.Created                         */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_955ExtValidsp01]  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR( 3),   
   @nStep            INT,   
   @nInputKey        INT,   
   @cFacility        NVARCHAR(20),  
   @cStorer          NVARCHAR(15),  
   @cPickSlipNo     NVARCHAR( 10) ,    
   @cSuggestedLOC   NVARCHAR( 10) ,  
   @cLOC            NVARCHAR( 10) ,  
   @cID             NVARCHAR( 18) ,  
   @cDropID         NVARCHAR( 20) ,  
   @cSKU            NVARCHAR( 20) ,  
   @cLottable01     NVARCHAR( 18) ,  
   @cLottable02     NVARCHAR( 18) ,  
   @cLottable03     NVARCHAR( 18) ,  
   @dLottable04     DATETIME      ,  
   @nTaskQTY        INT           ,  
   @nPQTY           INT           ,  
   @cUCC            NVARCHAR( 20) ,  
   @cOption         NVARCHAR( 1)  ,  
   @nErrNo           INT            OUTPUT,   
   @cErrMsg          NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE  @nStartPos  INT,  
            @nEndPos    INT  
               
   DECLARE  @cBarcode NVARCHAR( 60),  
            @cCartonBarcode NVARCHAR( 60)  
  
   DECLARE @cErrMsg1    NVARCHAR( 20),   
           @cErrMsg2    NVARCHAR( 20),  
           @cErrMsg3    NVARCHAR( 20),   
           @cErrMsg4    NVARCHAR( 20),  
           @cErrMsg5    NVARCHAR( 20),  
           @cOrderkey   NVARCHAR( 20),  
           @cPalletID   NVARCHAR( 20)  
  
   IF @nStep = 5  
   BEGIN  
      SELECT @cOrderkey=OrderKey  
      FROM dbo.PICKHEADER (NOLOCK)  
      WHERE PickHeaderKey=@cPickSlipNo  
  
      IF EXISTS (SELECT 1 FROM pickdetail (NOLOCK)  
                 WHERE dropid=@cDropID  
                 AND Storerkey=@cStorer  
                 AND orderkey=@cOrderkey  
                 AND id= @cID  
                 AND loc=@cSuggestedLOC  
                 AND sku=@cSKU  
                 AND status <='5')  
      BEGIN  
         SET @nErrNo = 173801   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DuplicateDropid  
         GOTO Quit  
      END  
  
      IF EXISTS(SELECT 1 FROM sku (NOLOCK)   
               WHERE sku=@csku  
               AND itemclass='MHD-POSM') AND @cDropID<>'X'   
  
      BEGIN  
         SET @nErrNo = 173803  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid dropid  
         GOTO Quit  
      END  
  
  
      IF @cDropID='X' AND EXISTS(SELECT 1 FROM sku (NOLOCK)   
                                 WHERE sku=@csku  
                                 AND itemclass<>'MHD-POSM')  
      BEGIN  
  
            IF EXISTS (SELECT 1 FROM sku (NOLOCK)   
                       WHERE sku=@csku  
                       AND EXISTS ( SELECT 1 FROM dbo.CODELKUP (NOLOCK)   
                                    WHERE LISTNAME='DROPIDREQ'  
                                    AND Storerkey=@cStorer  
                                    AND UDF01='Y'  
                                    AND code=skugroup))  
            BEGIN  
               SET @nErrNo = 173802  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid dropid  
               GOTO Quit  
            END  
      END  
   END  
QUIT:  
  
END -- End Procedure  
  

GO