SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1637ExtInfo03                                   */    
/* Copyright      : Maersk WMS                                          */    
/*                                                                      */    
/* Purpose: Display Total pallet qty                                    */    
/* Customer: Inditex                                                    */
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2024-06-16 1.0  NLT013   FCR-673 Created                             */   
/************************************************************************/    
    
CREATE PROCEDURE [rdt].[rdt_1637ExtInfo03]    
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cContainerNo              NVARCHAR( 20), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 30), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @cExtendedInfo1            NVARCHAR( 20) OUTPUT   

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE 
      @nTotalCnt              INT

   IF @nFunc = 1637
   BEGIN
      IF @nStep = 3
      BEGIN
         SELECT @nTotalCnt = COUNT(DISTINCT pkd.ID) 
         FROM dbo.MBOLDETAIL MBOLD WITH (NOLOCK)
         INNER JOIN dbo.PICKDETAIL pkd WITH(NOLOCK) ON MBOLD.OrderKey = pkd.OrderKey
         WHERE MBOLD.MBolKey = @cMBOLKEY
            AND pkd.StorerKey = @cStorerKey
            AND pkd.Status NOT IN ('4', '9')

         SET @cExtendedInfo1 = 'Total:' + ISNULL(TRY_CAST(@nTotalCnt AS NVARCHAR(5)), '0')
      END
   END
   
   
QUIT:    
END -- End Procedure  

GO