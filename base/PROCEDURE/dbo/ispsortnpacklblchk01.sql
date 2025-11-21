SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackLBLChk01                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check label no scanned, make sure it is not belong to       */  
/*          another consignee. If it is new label then it is allowed.   */  
/*                                                                      */
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2017-05-03 1.0  James    WMS907.Created                              */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackLBLChk01]  
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

   DECLARE @cErrMsg01        NVARCHAR( 20)
   
   SET @nErrNo = 0
   SET @cErrMsg01 = ''

   --IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
   --            JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   --            WHERE PH.ConsigneeKey <> @cConsigneeKey
   --            AND   PH.Status <> '9'
   --            AND   PD.LabelNo = @cLabelNo
   --            AND   PH.StorerKey = @cStorerKey)

   -- Check if label no exists in another consignee
   IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
               WHERE DropID = @cLabelNo
               AND   UDF01 <> @cConsigneeKey
               AND   LoadKey = @cLoadKey
               AND   [Status] < '9')
   BEGIN  
      SET @cErrMsg01 = rdt.rdtgetmessage( 108651, @cLangCode, 'DSP')--Lbl diff store 
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
      GOTO Quit  
   END     

   IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cLabelNo AND [Status] = '9')
   BEGIN
      SET @cErrMsg01 = rdt.rdtgetmessage( 108652, @cLangCode, 'DSP')--Ctn closed 
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
      GOTO Quit  
   END

QUIT:  
END -- End Procedure  

GO