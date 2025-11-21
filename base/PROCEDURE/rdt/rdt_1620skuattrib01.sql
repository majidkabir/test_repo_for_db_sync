SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1620SkuAttrib01                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: PVH Show SKU attribute                                      */  
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2019-01-18  1.0  James    WMS7588. Created                           */  
/* 2019-05-09  1.1  James    WMS8817. Add AltSKU (james01)              */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1620SkuAttrib01] (  
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

   SET @nSKUIsBlank = 0

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      SET @nSKUIsBlank = 1
   END

   SELECT @cDescr = Descr,
          @cAttribute01 = SUBSTRING( Descr, 1, 20),
          @cAttribute02 = Notes2,
          @cAttribute03 = Notes1
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nSKUIsBlank = 1
            SET @cDescr = ''-- short pick don't want show sku descr
      END

      GOTO Quit
   END

   GOTO Quit         
           
   Quit:
END  

GO