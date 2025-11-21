SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_ClusterPickSkuAttribute                         */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Show SKU attribute                                          */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2019-01-18  1.0  James    WMS7588. Created                           */  
/* 2019-05-09  1.1  James    WMS8817. Add AltSKU (james01)              */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_ClusterPickSkuAttribute] (  
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
   
   DECLARE @cExtendedSkuAttrib_SP      NVARCHAR( 20)
   DECLARE @cSQL                       NVARCHAR( MAX)
   DECLARE @cSQLParam                  NVARCHAR( MAX)
   DECLARE @cTempDescr                 NVARCHAR( 60)
   DECLARE @cTempStyle                 NVARCHAR( 20)
   DECLARE @cTempColor                 NVARCHAR( 10)
   DECLARE @cTempSize                  NVARCHAR( 5)
   DECLARE @cTempColor_Descr           NVARCHAR( 30)

   SET @cTempDescr = @cDescr
   SET @cTempStyle = @cStyle
   SET @cTempColor = @cColor
   SET @cTempSize = @cSize
   SET @cTempColor_Descr = @cColor_Descr

   SET @cAltSKU = ''
   SET @cDescr = ''
   SET @cStyle = ''
   SET @cColor = ''
   SET @cSize = ''
   SET @cColor_Descr = ''
   SET @cAttribute01 = ''
   SET @cAttribute02 = ''
   SET @cAttribute03 = ''
   SET @cAttribute04 = ''
   SET @cAttribute05 = ''
   SET @cAttribute06 = ''
   SET @cAttribute07 = ''
   SET @cAttribute08 = ''
   SET @cAttribute09 = ''
   SET @cAttribute10 = ''

   SELECT @cDescr = Descr,  
          @cStyle = Style,  
          @cColor = Color,  
          @cSize = Size,  
          @cColor_Descr =BUSR7
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SET @cExtendedSkuAttrib_SP = rdt.RDTGetConfig( @nFunc, 'ExtendedSkuAttrib_SP', @cStorerkey) 
   IF @cExtendedSkuAttrib_SP = '0'
      SET @cExtendedSkuAttrib_SP = ''

   IF @cExtendedSkuAttrib_SP <> '' AND 
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedSkuAttrib_SP AND type = 'P')
   BEGIN
      SET @nErrNo = 0
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedSkuAttrib_SP) +     
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cSKU, @cAltSKU OUTPUT, ' + 
         ' @cDescr OUTPUT, @cStyle OUTPUT, @cColor OUTPUT, @cSize OUTPUT, @cColor_Descr OUTPUT, ' + 
         ' @cAttribute01   OUTPUT, @cAttribute02   OUTPUT, @cAttribute03   OUTPUT,  ' + 
         ' @cAttribute04   OUTPUT, @cAttribute05   OUTPUT, @cAttribute06   OUTPUT,  ' + 
         ' @cAttribute07   OUTPUT, @cAttribute08   OUTPUT, @cAttribute09   OUTPUT,  ' + 
         ' @cAttribute10   OUTPUT, @nErrNo         OUTPUT, @cErrMsg        OUTPUT   '    
      SET @cSQLParam =    
         '@nMobile         INT,           ' +
         '@nFunc           INT,           ' +
         '@cLangCode       NVARCHAR( 3),  ' +
         '@nStep           INT,           ' +
         '@nInputKey       INT,           ' +
         '@cStorerkey      NVARCHAR( 15), ' +
         '@cSKU            NVARCHAR( 20), ' +
         '@cAltSKU         NVARCHAR( 30)  OUTPUT, ' + 
         '@cDescr          NVARCHAR( 60)  OUTPUT,  ' +
         '@cStyle          NVARCHAR( 20)  OUTPUT,  ' +  
         '@cColor          NVARCHAR( 10)  OUTPUT,  ' +
         '@cSize           NVARCHAR( 5)   OUTPUT,  ' +  
         '@cColor_Descr    NVARCHAR( 30)  OUTPUT,  ' +  
         '@cAttribute01    NVARCHAR( 20)  OUTPUT,  ' +
         '@cAttribute02    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute03    NVARCHAR( 20)  OUTPUT,  ' +
         '@cAttribute04    NVARCHAR( 20)  OUTPUT,  ' +
         '@cAttribute05    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute06    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute07    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute08    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute09    NVARCHAR( 20)  OUTPUT,  ' +  
         '@cAttribute10    NVARCHAR( 20)  OUTPUT,  ' +  
         '@nErrNo          INT            OUTPUT,   ' +
         '@cErrMsg         NVARCHAR( 20)  OUTPUT    ' 
               
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cSKU, @cAltSKU OUTPUT, 
         @cDescr OUTPUT, @cStyle OUTPUT, @cColor OUTPUT, @cSize OUTPUT, @cColor_Descr OUTPUT,
         @cAttribute01   OUTPUT, @cAttribute02   OUTPUT, @cAttribute03   OUTPUT, 
         @cAttribute04   OUTPUT, @cAttribute05   OUTPUT, @cAttribute06   OUTPUT, 
         @cAttribute07   OUTPUT, @cAttribute08   OUTPUT, @cAttribute09   OUTPUT, 
         @cAttribute10   OUTPUT, @nErrNo         OUTPUT, @cErrMsg        OUTPUT    

      IF @nErrNo <> 0
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

      GOTO Quit    
   END

   DECLARE @nSKUIsBlank    INT

   SET @nSKUIsBlank = 0

   IF ISNULL( @cSKU, '') = ''
   BEGIN
      SELECT @cSKU = V_SKU FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      SET @nSKUIsBlank = 1
   END

   IF @nSKUIsBlank = 1
   BEGIN
      SET @cDescr = @cTempDescr
      SET @cStyle = @cTempStyle
      SET @cColor = @cTempColor
      SET @cSize = @cTempSize
      SET @cColor_Descr = @cTempColor_Descr
   END
        
   GOTO Quit         
           
   Quit:
END  

GO