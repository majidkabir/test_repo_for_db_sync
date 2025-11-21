SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1017ExtValid01                                        */
/* Purpose:                                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-09-18 1.0  ChewKP   WMS-2882 Created                                  */
/******************************************************************************/

CREATE PROC rdt.rdt_1017ExtValid01 (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,          
   @nInputKey       INT,          
   @cStorerKey      NVARCHAR( 15), 
   @cWorkOrderNo    NVARCHAR( 20) OUTPUT, 
   @cSKU            NVARCHAR( 20), 
   @cMasterSerialNo NVARCHAR( 20), 
   @cBOMSerialNo    NVARCHAR( 20), 
   @cChildSerialNo  NVARCHAR( 20), 
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1017
BEGIN
   
   DECLARE @cPackKey       NVARCHAR(10) 
          ,@nCaseCnt       INT
          ,@cKitKey        NVARCHAR(10) 


   SET @nErrNo = 0

   IF @nStep = 1 -- WorkOrder
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.KIT WITH (NOLOCK) 
                         WHERE KitKey = @cWorkOrderNo ) 
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.KIT WITH (NOLOCK) 
                            WHERE ExternKitKey = @cWorkOrderNo ) 
            BEGIN
               SET @nErrNo = 115051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidKey
               GOTO Quit 
            END
            ELSE 
            BEGIN
               SELECT @cKitKey = KitKey 
               FROM dbo.KIT WITH (NOLOCK) 
               WHERE ExternKitKey = @cWorkOrderNo 
               
            END
                         
         END
         ELSE 
         BEGIN
            SET @cKitKey = @cWorkOrderNo
         END
         
         SET @cSKU = '' 
         
         SELECT TOP 1 
            @cSKU = SKU
         FROM dbo.KitDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND KITKey = @cKitKey
         AND Type = 'T'
         
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         IF ISNULL(@nCaseCnt,0 ) IN ( 0 , 1 ) 
         BEGIN
            SET @nErrNo = 115052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidCaseCnt
            GOTO Quit 
         END
         
         --SET @cKitKey = @cWorkOrderNo
         SET @cWorkOrderNo = @cKitKey
      END
   END

   IF @nStep = 2 --MasterSerialNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF LEN(@cMasterSerialNo) <> 10 
         BEGIN
            SET @nErrNo = 115061
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvMasterSerialNo
            GOTO Quit   
         END
         
         IF RIGHT(@cMasterSerialNo,1) <> 'C' 
         BEGIN
            SET @nErrNo = 115053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvMasterSerialNo
            GOTO Quit   
         END
         
          
         IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND Remarks = @cMasterSerialNo
                     AND Status = '9' ) 
         BEGIN
            SET @nErrNo = 115054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MasterSerialExist
            GOTO Quit 
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentSerialNo = @cMasterSerialNo)
         BEGIN
            SET @nErrNo = 115055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MasterSerialExist
            GOTO Quit               
         END
      END
   END
   
   IF @nStep = 3 --BOMSerialNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         IF RIGHT(@cBOMSerialNo,1) <> 'B' 
         BEGIN
            SET @nErrNo = 115056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvBOMSerialNo
            GOTO Quit   
         END
         
         IF LEN(@cBOMSerialNo) <> 10 
         BEGIN
            SET @nErrNo = 115063
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvBOMSerialNo
            GOTO Quit 
         END
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND ParentSerialNo = @cBOMSerialNo
                     AND Status = '9' ) 
         BEGIN
            SET @nErrNo = 115057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BOMSerialExist
            GOTO Quit 
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentSerialNo = @cBOMSerialNo)
         BEGIN
            SET @nErrNo = 115058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BOMSerialExist
            GOTO Quit               
         END
      END
   END
   
   IF @nStep = 4 -- ChildSerialNo 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
        IF EXISTS ( SELECT 1 FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey
                    AND FromSerialNo = @cChildSerialNo ) 
        BEGIN
            SET @nErrNo = 115059
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ChildSerialExist
            GOTO Quit 
        END
        
        IF EXISTS ( SELECT 1 FROM dbo.MasterSerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   SerialNo = @cChildSerialNo)
        BEGIN
            SET @nErrNo = 115060
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ChildSerialExist
            GOTO Quit               
        END
         
         
         
      END
      
   END
END

Quit:



GO