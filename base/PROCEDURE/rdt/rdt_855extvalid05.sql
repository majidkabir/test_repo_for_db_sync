SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtValid05                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Check user input qty vs system qty. If both value not same  */  
/*          prompt screen to alert user                                 */
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2023-07-26  1.0  yeekung  WMS-23057. Created                         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtValid05] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @cStorer        NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @cLoadKey       NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cID            NVARCHAR( 18) = '',
   @cTaskDetailKey NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nInputKey      INT,
           @cWavekey       NVARCHAR( 10)
           
   -- Variable mapping

   IF @nFunc = 855   -- Drop ID
   BEGIN
      IF @nStep = 1  -- Carton ID entered
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cWavekey = wavekey
            FROM Pickdetail (NOLOCK)
            Where Dropid = @cDropID
               AND Storerkey = @cStorer
               AND Status in ('5')

            IF NOT EXISTS ( SELECT 1
                        FROM WAVE (nolock)
                        WHERE Wavekey = @cWavekey
                           AND LoadPlanGroup = 'WVLPGRP04'
                           AND ISNULL(UserDefine02,'') = ''
                           AND ISNULL(UserDefine03,'') ='')
            BEGIN
               SET @nErrNo = 204351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CartonNotPick
               GOTO Quit
            END
            
         END
      END
   END

   Quit:      

END  


GO