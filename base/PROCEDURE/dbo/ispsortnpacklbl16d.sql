SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackLBL16d                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*          Copied from ispSortNPackLBLChk but this version validate    */  
/*          validate label with 16 digits                               */
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-04-02 1.0  James    SOS307345 Created                           */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackLBL16d]  
   @nMobile       INT,   
   @nFunc         INT,   
   @cLangCode     NVARCHAR(3),  
   @cLoadKey      NVARCHAR(10),  
   @cConsigneeKey NVARCHAR(15),  
   @cStorerKey    NVARCHAR(15),  
   @cSKU          NVARCHAR(20),  
   @cLabelNo      NVARCHAR(20),  
   @nErrNo        INT      OUTPUT,   
   @cErrMsg       NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSectionKey    NVARCHAR(10)  
   DECLARE @cUserDefine02  NVARCHAR(20)  
   DECLARE @cSUSR1         NVARCHAR(20)  
   DECLARE @cFacility      NVARCHAR(5)  
  
   SET @cSectionKey = ''  
   SET @cUserDefine02 = '' 
   SET @cSUSR1 = '' 


   IF LEN(RTRIM(@cLabelNo)) <> 16   
   BEGIN
      SET @nErrNo = 1  
      GOTO Quit
   END

   SELECT @cFacility = Facility 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SELECT @cSUSR1 = ISNULL(UDF01, '') 
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'ITXWH'
   AND   Code = @cFacility
   AND StorerKey = @cStorerKey
   
   -- Get order info  
   SELECT TOP 1   
      @cSectionKey = ISNULL( O.SectionKey, ''),   
      @cUserDefine02 = O.UserDefine02  
   FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
   WHERE LPD.LoadKey = @cLoadKey  
      AND PD.StorerKey = @cStorerKey  
      AND PD.SKU = CASE WHEN ISNULL(@cSKU, '') = '' THEN PD.SKU ELSE @cSKU END 
      AND PD.Status = '0'  
      AND O.ConsigneeKey = @cConsigneeKey --Exclude current consignee  
      AND ISNULL(OD.UserDefine04, '') <> 'M' 
   ORDER BY O.OrderKey  

   IF SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 1, 4) <> RIGHT( '0000' + RTRIM(LTRIM(@cSUSR1)), 4) OR 
      SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 5, 4) <> RIGHT( '0000' + REPLACE( @cConsigneeKey, 'ITX', ''), 4) OR 
      SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 9, 1) <> @cSectionKey OR 
      SUBSTRING( RTRIM(LTRIM(@cLabelNo)), 10, 1) <> @cUserDefine02 
   BEGIN  
      SET @nErrNo = 1  
      GOTO Quit
   END  
   
QUIT:  
END -- End Procedure  

GO