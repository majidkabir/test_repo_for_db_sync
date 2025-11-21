SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1621SkuAttrib01                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Yvesr Show SKU Descr + Lottable12                           */  
/*                                                                      */  
/* Called from: rdt_ClusterPickSkuAttribute                             */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2021-04-14  1.0  James    WM-16766. Created                          */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_1621SkuAttrib01] (  
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
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLot           NVARCHAR( 10)
   DECLARE @cLottable12    NVARCHAR( 30)
 
   SELECT @cOrderKey = V_OrderKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile 

   SELECT @cDescr = DESCR
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   Sku = @cSKU
   
   SELECT TOP 1 @cLot = Lot
   FROM rdt.rdtPickLock RPL WITH (NOLOCK)
   WHERE RPL.Orderkey = @cOrderKey
   AND   RPL.SKU = @cSKU
   AND   RPL.[Status] = '1'
   AND   RPL.Mobile = @nMobile
   AND   EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                  WHERE RPL.Orderkey = PD.OrderKey
                  AND   RPL.Loc = PD.Loc
                  AND   RPL.SKU = PD.Sku
                  AND   PD.[Status] = '0')
   ORDER BY 1
   
   SELECT @cLottable12 = Lottable12
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @cLot
   
   SELECT @cDescr = SUBSTRING( ISNULL( RTRIM( @cLottable12), '') + ISNULL( @cDescr, ''), 1, 60)

   Quit:

END  

GO