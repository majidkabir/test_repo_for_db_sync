SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1016ExtInfo01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display Count                                               */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2017-09-12 1.0  ChewKP   WMS-2881 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1016ExtInfo01] (
  @nMobile         INT,       
  @nFunc           INT,         
  @cLangCode       NVARCHAR( 3), 
  @nStep           INT,         
  @nInputKey       INT,         
  @cStorerKey      NVARCHAR( 15),
  @cWorkOrderNo    NVARCHAR( 10),
  @cSKU            NVARCHAR( 20),
  @cMasterSerialNo NVARCHAR( 20),
  @cChildSerialNo  NVARCHAR( 20),
  @cOutPutText     NVARCHAR( 20) OUTPUT, 
  @nErrNo          INT OUTPUT,    
  @cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCaseCnt     INT
          ,@nScanCount   INT
          ,@cUserName    NVARCHAR(18) 
          ,@cPackKey     NVARCHAR(10) 
          
   SELECT @cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
          
   IF @nStep = 3 
   BEGIN
      IF @nInputKey IN ( 1, 0 )  -- ENTER
      BEGIN
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         SELECT @nScanCount = Count(RowRef) 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND ParentSerialNo = @cMasterSerialNo
         AND Status = '1'
         
         

         SET @cOutPutText = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nCaseCnt As VARCHAR(5)), 5)  
         --SELECT @nScanCount '@nScanCount' , @nCaseCnt '@nCaseCnt' , @cOutPutText '@cOutPutText' 
      END
   END

GO