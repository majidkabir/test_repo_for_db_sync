SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1620SkuAttrib02                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: PVH Show SKU attribute                                      */  
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2019-01-18  1.0  James    WMS7588. Created                           */  
/* 2019-05-09  1.1  James    WMS8817. Add AltSKU (james01)              */  
/* 2019-06-21  1.2  James    INC0739292 - Bug Fix (james02)             */
/* 2019-09-10  1.3  LZG      INC0849526 - Order by RowRef to get latest */
/*                           record (ZG01)                              */
/************************************************************************/  

CREATE PROC [RDT].[rdt_1620SkuAttrib02] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
   @cAltSKU       NVARCHAR( 30)  OUTPUT,  
   @cDescr        NVARCHAR( 60)  OUTPUT,  
   @cStyle        NVARCHAR( 20)  OUTPUT,  
   @cColor        NVARCHAR( 10)  OUTPUT,  
   @cSize         NVARCHAR( 5)   OUTPUT,  
   @cColor_Descr  NVARCHAR( 30)  OUTPUT,  
   @cAttribute01  NVARCHAR( 20)  OUTPUT,  
   @cAttribute02  NVARCHAR( 20)  OUTPUT,  
   @cAttribute03  NVARCHAR( 20)  OUTPUT,  
   @cAttribute04  NVARCHAR( 20)  OUTPUT,  
   @cAttribute05  NVARCHAR( 20)  OUTPUT,  
   @cAttribute06  NVARCHAR( 20)  OUTPUT,  
   @cAttribute07  NVARCHAR( 20)  OUTPUT,  
   @cAttribute08  NVARCHAR( 20)  OUTPUT,  
   @cAttribute09  NVARCHAR( 20)  OUTPUT,  
   @cAttribute10  NVARCHAR( 20)  OUTPUT,  
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @nSKUIsBlank    INT
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cDropID        NVARCHAR( 20)

   SELECT @cUserName = UserName, 
          @cDropID = V_String17
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nSKUIsBlank = 0

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      SET @nSKUIsBlank = 1
   END

   SELECT @cAttribute01 = MANUFACTURERSKU
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   IF @nStep = 7 -- (james02)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- In step 7, drop id inserted into rdtpickloc upon scanning
         SELECT TOP 1 @cAttribute02 = DropID
         FROM rdt.RDTPickLock WITH (NOLOCK)
         WHERE AddWho = @cUserName
         AND   Status = '1'
         AND   SKU = @cSKU
         AND   Mobile = @nMobile
         --ORDER BY EditDate DESC      -- ZG01
         ORDER BY RowRef DESC          -- ZG01
      END
   END

   IF @nStep = 8 -- (james02)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nSKUIsBlank = 1
            SET @cDescr = ''-- short pick don't want show sku descr

         SET @cAttribute02 = @cDropID
      END

      GOTO Quit
   END

   GOTO Quit         
           
   Quit:
END  

GO