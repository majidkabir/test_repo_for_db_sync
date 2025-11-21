SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_SkuLabel07rpt                                   */  
/* Creation Date: 30-Oct-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-6800 & WMS-14862 - THG WMS Report - Receipt SKU Label   */  
/*                                                                      */  
/* Called By: PowerBuilder                                              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_SkuLabel07rpt]  
   --     @cDataWidnow     NVARCHAR(40)
        @c_Storerkey      NVARCHAR(40)
      , @c_Sku            NVARCHAR(4000)
      , @n_Casecnt        NVARCHAR(4000)
      , @NoofLabel        NVARCHAR(4000)
AS  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  

--SET @cDataWidnow = 'r_hk_price_tag_label_02'
--SET @cStorerkey  = :as_storerkey
--SET @cSku        = :as_sku
--SET @nCasecnt    = :as_casecnt
--SET @NoofLabel   = :as_nooflabel

   SELECT Storerkey = SKU.Storerkey
        , SKU       = SKU.SKU
        , ALTSKU    = SKU.ALTSKU
        , Casecnt   = @n_Casecnt
        , NoOfLabel = @NoofLabel
        , SeqNo     = SeqTbl.seqno
   FROM dbo.SKU SKU (NOLOCK)
   
   JOIN (
      SELECT TOP 10000 seqno = ROW_NUMBER () OVER (ORDER BY Storerkey) FROM SKU (NOLOCK)
   ) AS SeqTbl ON SeqTbl.seqno <= CAST(@NoofLabel AS INT)
   
   WHERE Storerkey = @c_Storerkey
     AND SKU = @c_Sku
   
   ORDER BY SeqTbl.seqno

GO