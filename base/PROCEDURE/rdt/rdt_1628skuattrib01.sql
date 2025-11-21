SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1628SkuAttrib01                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: PVH Show SKU attribute                                      */  
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2020-08-06  1.0  James    WMS-14525. Created                         */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1628SkuAttrib01] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
   @cAltSKU       NVARCHAR( 20)  OUTPUT,
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
   DECLARE @cDropID        NVARCHAR( 20)
   
   SELECT @cAttribute01 = ''
   SELECT @cAttribute02 = ''
   SELECT @cAttribute03 = ''
   
   SET @nSKUIsBlank = 0

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      SET @nSKUIsBlank = 1
   END

   IF @nStep = 7
   BEGIN
      SELECT @cDropID = I_Field10
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SELECT @cAttribute04 = @cDropID
   END
   ELSE
   BEGIN
      SELECT @cDropID = V_String17
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SELECT @cAttribute04 = @cDropID      
   END
   
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