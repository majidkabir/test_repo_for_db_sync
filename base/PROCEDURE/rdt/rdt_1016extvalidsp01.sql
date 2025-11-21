SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1016ExtValidSP01                                      */
/* Purpose:                                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-09-08 1.0  ChewKP   WMS-2881 Created                                  */
/* 2018-12-24 1.1  ChewKP   WMS-7274 CR.                                      */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1016ExtValidSP01] (
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
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1016
BEGIN
   
   DECLARE @cPackKey       NVARCHAR(10) 
          ,@nCaseCnt       INT
         
         


   SET @nErrNo = 0

   IF @nStep = 1 -- WorkOrder
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         IF ISNULL(@nCaseCnt,0 ) IN ( 0 , 1 ) 
         BEGIN
            SET @nErrNo = 114451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidCaseCnt
            GOTO Quit 
         END
         

      END
   END

   IF @nStep = 2 --MasterSerialNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF LEN(@cMasterSerialNo) <> 10 
         BEGIN
            SET @nErrNo = 114458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvMasterSerialNo
            GOTO Quit  
         END
         
         IF RIGHT(@cMasterSerialNo,1) <> 'C' 
         BEGIN
            SET @nErrNo = 114452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvMasterSerialNo
            GOTO Quit   
         END
         
         IF LEN(@cMasterSerialNo) <> 10 
         BEGIN
            SET @nErrNo = 114459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvMasterSerialNo
            GOTO Quit 
         END
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND SourceKey = @cWorkOrderNo
                     AND ParentSerialNo = @cMasterSerialNo ) 
         BEGIN
            SET @nErrNo = 114455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MasterSerialExist
            GOTO Quit 
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentSerialNo = @cMasterSerialNo)
         BEGIN
            SET @nErrNo = 114453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MasterSerialExist
            GOTO Quit               
         END
      END
   END
   
   IF @nStep = 3 -- ChildSerialNo 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
        IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND SourceKey = @cWorkOrderNo
                     AND FromSerialNo = @cChildSerialNo ) 
        BEGIN
            SET @nErrNo = 114456
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ChildSerialExist
            GOTO Quit 
        END
        
        IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentSerialNo = @cMasterSerialNo)
        BEGIN
            SET @nErrNo = 114454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ChildSerialExist
            GOTO Quit               
        END
        
        IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentSerialNo = @cMasterSerialNo
                     AND   SerialNo  = @cChildSerialNo)
        BEGIN
            SET @nErrNo = 114457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ChildSerialExist
            GOTO Quit 
        END
         
         
         
      END
      
   END
END

Quit:



GO