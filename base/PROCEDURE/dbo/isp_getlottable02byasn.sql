SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_GetLottable02ByAsn                             */    
/* Creation Date: 29-Jun-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: James                                                    */    
/*                                                                      */    
/* Purpose:  SOS#224115 Project LCI - Show drop down Lottable02         */    
/*                                                                      */    
/* Input Parameters:  @nMobile                                          */    
/*                                                                      */    
/* Called By:  rdtfnc_UCCCarton_Receive                                 */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 11/10/2011   ChewKP        Changes to use Log Table (ChewKP01)       */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetLottable02ByAsn] (    
   @nMobile       int   
)     
AS    
BEGIN    
     
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   --DELETE FROM rdt.rdtDropDown_Log -- (ChewKP01)  
   ---WHERE Mobile = @nMobile  
     
     
-- (ChewKP01)  
--   IF (SELECT COUNT( DISTINCT Lottable02) FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
--   JOIN RDT.RDTMobRec MOB WITH (NOLOCK)   
--   ON (RD.StorerKey = MOB.StorerKey AND RD.ReceiptKey = MOB.V_ReceiptKey AND RD.SKU = MOB.V_SKU)  
--   WHERE MOB.Mobile = @nMobile  
--   AND ISNULL(RD.Lottable02, '') <> '') > 1  
--   BEGIN  
--      IF Object_ID('tempdb..#TEMP_RECEIPTDETAIL_LOT02') IS NOT NULL  
--         DROP TABLE #TEMP_RECEIPTDETAIL_LOT02  
--  
--      SELECT DISTINCT Lottable02 AS Label, Lottable02 AS ColText INTO #TEMP_RECEIPTDETAIL_LOT02  
--      FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
--      JOIN RDT.RDTMobRec MOB WITH (NOLOCK)   
--      ON (RD.StorerKey = MOB.StorerKey AND RD.ReceiptKey = MOB.V_ReceiptKey AND RD.SKU = MOB.V_SKU)  
--      WHERE MOB.Mobile = 11--@nMobile  
--      AND ISNULL(RD.Lottable02, '') <> ''  
--  
--      INSERT INTO #TEMP_RECEIPTDETAIL_LOT02 (Label, ColText) VALUES ('', '')  
--      DECLARE CUR_FORMAT CURSOR FAST_FORWARD READ_ONLY FOR   
--      SELECT Label, ColText FROM #TEMP_RECEIPTDETAIL_LOT02 ORDER BY 1  
--   END  
--   ELSE  
--   BEGIN  
--      DECLARE CUR_FORMAT CURSOR FAST_FORWARD READ_ONLY FOR      
--      SELECT DISTINCT Lottable02 AS Label, Lottable02 AS ColText FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
--      JOIN RDT.RDTMobRec MOB WITH (NOLOCK)   
--      ON (RD.StorerKey = MOB.StorerKey AND RD.ReceiptKey = MOB.V_ReceiptKey AND RD.SKU = MOB.V_SKU)  
--      WHERE MOB.Mobile = @nMobile  
--      AND ISNULL(RD.Lottable02, '') <> ''  
--   END  
  
      --INSERT INTO rdt.rdtDropDown_Log (Mobile, LabelText , LabelValue)  
      SELECT DISTINCT Lottable02 AS Label, Lottable02 AS ColText 
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
      JOIN RDT.RDTMobRec MOB WITH (NOLOCK)   
      ON (RD.StorerKey = MOB.StorerKey AND RD.ReceiptKey = MOB.V_ReceiptKey)  
      WHERE MOB.Mobile = @nMobile  
      AND ISNULL(RD.Lottable02, '') <> ''  
      AND RD.SKU = CASE WHEN ISNULL(MOB.V_SKU,'') = '' THEN RD.SKU ELSE MOB.V_SKU END 
      AND RD.POKey = CASE WHEN ISNULL(MOB.V_POKey,'') = '' OR MOB.V_POKey = 'NOPO' 
                               THEN RD.POKey 
                          ELSE MOB.V_POKey 
                     END
        
END

GO