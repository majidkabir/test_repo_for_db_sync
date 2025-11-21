SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_GetScnByPalletID                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: If receiving by pallet then goto ID screen                  */
/*          else goto SKU screen                                        */
/*          Called from rdtfnc_NormalReceipt                            */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-03-27 1.0  James    SOS305458 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_GetScnByPalletID]    
   @nMobile         INT, 
   @cStorer         NVARCHAR( 15),     
   @cReceiptKey     NVARCHAR( 10),    
   @cID             NVARCHAR( 18),       
   @nScn            INT,       
   @nStep           INT, 
   @nO_Scn          INT       OUTPUT, 
   @nO_Step         INT       OUTPUT, 
   @nValid          INT       OUTPUT  
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @nSKUCount      INT, 
           @cO_ID          NVARCHAR( 18), 
           @cO_LOC         NVARCHAR( 10) 

   SET @nValid = 1
   
   IF ISNULL( @cID, '') <> '' 
   BEGIN
      SET @nO_Scn = 953
      SET @nO_Step = 3
      GOTO Quit
   END
   ELSE
   BEGIN
      SET @nO_Scn = 954
      SET @nO_Step = 4
      GOTO Quit
   END
/*
   SET @nSKUCount = 0

   SELECT @nSKUCount = COUNT( DISTINCT SKU)
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
   AND   ReceiptKey = @cReceiptKey
   AND   ToID = @cID
   
   IF @nSKUCount = 1
   BEGIN
      -- If 1 pallet only contain 1 SKU
      -- goto pallet id screen
      SET @nO_Scn = 953
      SET @nO_Step = 3
   END
*/
   QUIT:    

END -- End Procedure    

GO