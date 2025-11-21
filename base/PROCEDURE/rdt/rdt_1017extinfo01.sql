SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1017ExtInfo01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display Count                                               */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2017-09-18 1.0  ChewKP   WMS-2882 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1017ExtInfo01] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,          
   @nInputKey       INT,          
   @cStorerKey      NVARCHAR( 15), 
   @cWorkOrderNo    NVARCHAR( 10), 
   @cSKU            NVARCHAR( 20) OUTPUT , 
   @cMasterSerialNo NVARCHAR( 20), 
   @cBOMSerialNo    NVARCHAR( 20), 
   @cChildSerialNo  NVARCHAR( 20), 
   @cOutText1       NVARCHAR( 60) OUTPUT,
   @cOutText2       NVARCHAR( 20) OUTPUT,
   @cOutText3       NVARCHAR( 20) OUTPUT,
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
          ,@cKitKey      NVARCHAR(10) 
          ,@cSKUDescr    NVARCHAR(60) 
          ,@nTTLPCS      INT
          
   SELECT @cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
          
   IF @nStep = 2 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         IF EXISTS ( SELECT 1 FROM dbo.KIT WITH (NOLOCK) 
                         WHERE KitKey = @cWorkOrderNo ) 
         BEGIN
            SET @cKitKey = @cWorkOrderNo
         END
         ELSE
         BEGIN
               SELECT @cKitKey = KitKey 
               FROM dbo.KIT WITH (NOLOCK) 
               WHERE ExternKitKey = @cWorkOrderNo 
         END                 

         
         SET @cSKU = '' 
         
         SELECT TOP 1 
            @cSKU = SKU
         FROM dbo.KitDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND KITKey = @cKitKey
         AND Type = 'T'
         
         
         SELECT @cSKUDescr = Descr 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SET @cOutText1 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutText2 = SUBSTRING( @cSKUDescr, 21, 20)
         
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         SELECT @nScanCount = Count(DISTINCT ParentSerialNo)
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         --AND Status = '1'

         --SELECT @nCaseCnt '@nCaseCnt' , @nScanCount '@nScanCount' , @cMasterSerialNo '@cMasterSerialNo'
         
         
         SET @cOutText3 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nCaseCnt As VARCHAR(5)), 5)  

         --PRINT @cOutText3
      END
   END
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1 
      BEGIN
         SELECT @nScanCount = Count(RowRef) 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         AND ParentSerialNo = @cBOMSerialNo
         AND Status = '1'
         
         SELECT @nTTLPCS = SUM(QTY) 
         FROM dbo.BILLOFMATERIAL B WITH (NOLOCK)
         INNER JOIN dbo.SKU S WITH (NOLOCK) ON S.SKU=B.COMPONENTSKU AND S.SUSR4='AD' AND S.STORERKEY=B.STORERKEY
         WHERE B.StorerKey = @cStorerKey
         AND B.SKU=@cSKU
         GROUP BY B.SKU

         SET @cOutText1 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nTTLPCS As VARCHAR(5)), 5)  
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nScanCount = Count(RowRef) 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         AND ParentSerialNo = @cBOMSerialNo
         AND Status = '1'
         
         SELECT @nTTLPCS = SUM(QTY) 
         FROM dbo.BILLOFMATERIAL B WITH (NOLOCK)
         INNER JOIN dbo.SKU S WITH (NOLOCK) ON S.SKU=B.COMPONENTSKU AND S.SUSR4='AD' AND S.STORERKEY=B.STORERKEY
         WHERE B.StorerKey = @cStorerKey
         AND B.SKU=@cSKU
         GROUP BY B.SKU

--         IF NOT EXISTS ( SELECT 1  FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
--                     WHERE StorerKey = @cStorerKey
--                     AND Func = @nFunc
--                     AND AddWho = @cUserName
--                     AND ParentSerialNo = @cMasterSerialNo
--                     AND ParentSerialNo = @cBOMSerialNo
--                     AND Status = '1' )
--         BEGIN
--            SELECT @cSKUDescr = Descr 
--            FROM dbo.SKU WITH (NOLOCK) 
--            WHERE StorerKey = @cStorerKey
--            AND SKU = @cSKU 
--         
--            SET @cOutText1 = SUBSTRING( @cSKUDescr, 1, 20)
--            SET @cOutText2 = SUBSTRING( @cSKUDescr, 21, 20)
--         END
--         ELSE
--         BEGIN
            SET @cOutText1 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nTTLPCS As VARCHAR(5)), 5)  
--         END
      END
      
      IF @nInputKey = 0 -- ESC
      BEGIN
         
         IF EXISTS ( SELECT 1 FROM dbo.KIT WITH (NOLOCK) 
                         WHERE KitKey = @cWorkOrderNo ) 
         BEGIN
            SET @cKitKey = @cWorkOrderNo
         END
         ELSE
         BEGIN
               SELECT @cKitKey = KitKey 
               FROM dbo.KIT WITH (NOLOCK) 
               WHERE ExternKitKey = @cWorkOrderNo 
         END                 

         
         --SET @cSKU = '' 
         
         --SELECT TOP 1 
         --   SKU = @cSKU 
         --FROM dbo.KitDetail WITH (NOLOCK) 
         --WHERE StorerKey = @cStorerKey
         --AND KITKey = @cKitKey
         --AND Type = 'T'
         
         
         SELECT @cSKUDescr = Descr 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SET @cOutText1 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutText2 = SUBSTRING( @cSKUDescr, 21, 20)
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         SELECT @nScanCount = Count(DISTINCT ParentSerialNo)
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         --AND Status = '1'

         --SELECT @nCaseCnt '@nCaseCnt' , @nScanCount '@nScanCount' , @cMasterSerialNo '@cMasterSerialNo'
         
         
         SET @cOutText3 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nCaseCnt As VARCHAR(5)), 5)  


      END
   END
   
   IF @nStep = 5 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         IF EXISTS ( SELECT 1 FROM dbo.KIT WITH (NOLOCK) 
                         WHERE KitKey = @cWorkOrderNo ) 
         BEGIN
            SET @cKitKey = @cWorkOrderNo
         END
         ELSE
         BEGIN
               SELECT @cKitKey = KitKey 
               FROM dbo.KIT WITH (NOLOCK) 
               WHERE ExternKitKey = @cWorkOrderNo 
         END                 

         
         SET @cSKU = '' 
         
         SELECT TOP 1 
            @cSKU = SKU
         FROM dbo.KitDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND KITKey = @cKitKey
         AND Type = 'T'
         
         
         SELECT @cSKUDescr = Descr 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 
         
         SET @cOutText1 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutText2 = SUBSTRING( @cSKUDescr, 21, 20)
         
         
         SELECT @cPackKey = PackKey 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU 

         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack WITH (NOLOCK) 
         WHERE Packkey = @cPackKey
         
         SELECT @nScanCount = Count(DISTINCT ParentSerialNo)
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         --AND Status = '1'

         --SELECT @nCaseCnt '@nCaseCnt' , @nScanCount '@nScanCount' , @cMasterSerialNo '@cMasterSerialNo'
         
         
         SET @cOutText3 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nCaseCnt As VARCHAR(5)), 5)  

         --PRINT @cOutText3
      END
      
      IF @nInputKey = 0 -- ENTER
      BEGIN
         SELECT @nScanCount = Count(RowRef) 
         FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND Func = @nFunc
         AND AddWho = @cUserName
         AND Remarks = @cMasterSerialNo
         AND ParentSerialNo = @cBOMSerialNo
         AND Status = '1'
         
         SELECT @nTTLPCS = SUM(QTY) 
         FROM dbo.BILLOFMATERIAL B WITH (NOLOCK)
         INNER JOIN dbo.SKU S WITH (NOLOCK) ON S.SKU=B.COMPONENTSKU AND S.SUSR4='AD' AND S.STORERKEY=B.STORERKEY
         WHERE B.StorerKey = @cStorerKey
         AND B.SKU=@cSKU
         GROUP BY B.SKU

--         IF NOT EXISTS ( SELECT 1  FROM rdt.rdtSerialNoLog WITH (NOLOCK) 
--                     WHERE StorerKey = @cStorerKey
--                     AND Func = @nFunc
--                     AND AddWho = @cUserName
--                     AND ParentSerialNo = @cMasterSerialNo
--                     AND ParentSerialNo = @cBOMSerialNo
--                     AND Status = '1' )
--         BEGIN
--            SELECT @cSKUDescr = Descr 
--            FROM dbo.SKU WITH (NOLOCK) 
--            WHERE StorerKey = @cStorerKey
--            AND SKU = @cSKU 
--         
--            SET @cOutText1 = SUBSTRING( @cSKUDescr, 1, 20)
--            SET @cOutText2 = SUBSTRING( @cSKUDescr, 21, 20)
--         END
--         ELSE
--         BEGIN
            SET @cOutText1 = RIGHT(Replicate(' ',5) + CAST(@nScanCount As VARCHAR(5)), 5)  + ' / ' + RIGHT(Replicate(' ',5) + CAST(@nTTLPCS As VARCHAR(5)), 5)  
--         END
      END
      
   END

GO