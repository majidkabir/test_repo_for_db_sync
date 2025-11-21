SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPrtPalletManChk01                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Print Pallet Manisfest Drop ID check SP                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2013-06-28 1.0  James    SOS282610 - Created (james01)               */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPrtPalletManChk01]  
   @nMobile       INT,   
   @nFunc         INT,   
   @cLangCode     NVARCHAR(3),  
   @cDropID       NVARCHAR(20),  
   @cStorer       NVARCHAR(20),  
   @cParm1        NVARCHAR(20),  -- Report type
   @cParm2        NVARCHAR(20),  
   @cParm3        NVARCHAR(20),  
   @cParm4        NVARCHAR(20),  
   @cParm5        NVARCHAR(20),  
   @nErrNo        INT          OUTPUT,   
   @cErrMsg       NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cLoadKey    NVARCHAR( 10)
   
   SET @nErrNo = 0
   
   IF ISNULL(@cParm1, '') <> 'CTNMNFSTID' -- Report type
      GOTO Quit

   IF ISNULL(@cDropID, '') = ''
   BEGIN
      SET @nErrNo = 1   
      SET @cErrMsg = 'DROP ID BLANK'
      GOTO Quit
   END
   
   -- Get LoadKey. Assumption 1 DropID exists in 1 Load
   SELECT TOP 1 @cLoadKey = PH.LoadKey 
	FROM dbo.PackHeader PH WITH (NOLOCK)  
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PD.DropID  = @cDropID
   AND   PD.StorerKey = @cStorer
   
   IF ISNULL(@cLoadKey, '') = ''
   BEGIN
      SET @nErrNo = 1   
      SET @cErrMsg = 'LOADKEY NOT FOUND'
      GOTO Quit
   END
   
   IF EXISTS (SELECT 1 
              FROM dbo.PackHeader WITH (NOLOCK)
              WHERE LoadKey = @cLoadKey
              AND   StorerKey = @cStorer
              AND   Status < '9')
   BEGIN
      SET @nErrNo = 1   
      SET @cErrMsg = 'PACK NOT CONFIRM'
      GOTO Quit
   END
   
   IF EXISTS (SELECT 1 
              FROM dbo.PickDetail PD WITH (NOLOCK) 
              JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
              WHERE LPD.LoadKey = @cLoadKey
              AND   PD.StorerKey = @cStorer
              AND   PD.Status < '5')
   BEGIN
      SET @nErrNo = 1   
      SET @cErrMsg = 'PICK IN PROGRESS'
      GOTO Quit
   END
   
QUIT:  
END -- End Procedure  

GO