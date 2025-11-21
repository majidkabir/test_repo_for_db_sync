SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/  
/* Store procedure: rdt_512ExtUpd01                                     */  
/* Purpose:        Update ID.UDF01                                      */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-11-28 1.0  XLL045     FCR-759 ID and UCC Length Issue           */  
/************************************************************************/ 

CREATE   PROC [RDT].[rdt_512ExtUpd01] ( 
   @nMobile      INT,               
  @nFunc        INT,               
  @cLangCode    NVARCHAR( 3),      
  @nStep        INT,               
  @nInputKey    INT,               
  @cStorerKey   NVARCHAR( 15),        
  @cBarcode     NVARCHAR( 60),
  @cSKU         NVARCHAR( 20)  OUTPUT,
  @nQTY         INT            OUTPUT,
  @cToID		    NVARCHAR( 18)  OUTPUT,
  @cFromLOC     NVARCHAR( 10)  OUTPUT,
  @cToLOC       NVARCHAR( 10)  OUTPUT,
  @nErrNo       INT            OUTPUT,
  @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nStep_LOC     INT
   DECLARE  @cID           NVARCHAR(18)
   DECLARE  @cUDF01        NVARCHAR(7)
   DECLARE  @cPACKKEY      NVARCHAR(10)
   

         
   IF @cBarcode <> ''
   BEGIN
      
      IF LEN(LTRIM(RTRIM(@cBarcode))) <> 25
      BEGIN
         SET @nErrNo =  226401
         SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
         GOTO Quit
      END
         
      SET @cId = RIGHT(LTRIM(RTRIM(@cBarcode)),18)
      SET @cUDF01 = LEFT(LTRIM(RTRIM(@cBarcode)), 7)
      IF EXISTS(SELECT 1 FROM dbo.LOC where LoseId = 1 and loc = @cToLOC )
      BEGIN
        GOTO Quit
      END
      IF EXISTS(SELECT 1 FROM dbo.ID where id = @cId)
      BEGIN   
          
         UPDATE dbo.ID set UserDefine01 = @cUDF01 where id = @cId
         
      END
      ELSE
      BEGIN
          
         SELECT @cPackKey = PACKKey from dbo.SKU where StorerKey = @cStorerKey
         INSERT INTO dbo.ID(Id,Qty,Packkey,UserDefine01) VALUES(@cId,@nQTY,@cPackKey,@cUDF01)

      END
      IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 226751  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, N'DSP') --'UpdUDF01Fail'  
            GOTO Quit  
         END
      GOTO Quit
   END

   Quit:

END
GO