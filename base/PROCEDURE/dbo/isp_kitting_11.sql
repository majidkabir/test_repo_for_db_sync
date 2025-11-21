SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_kitting_11                                      */
/* Creation Date: 13-SEP-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-17888 CN REMY Kitting Tally Sheet                      */
/*                                                                      */
/*                                                                      */
/* Input Parameters: @c_kitkey                                          */
/*                                                                      */
/* Usage: Call by dw = r_dw_kitting_11                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-OCT-2021  CSCHONG   1.0   Devops scripts combine                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_kitting_11] (@c_kitkey NVARCHAR(10) )
AS
BEGIN 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Qty          INT
         , @n_QtyToTake    INT
         , @n_QtyAvailable INT
         , @c_Storerkey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @c_lot          NVARCHAR(10)
         , @c_loc          NVARCHAR(10)
         , @c_id           NVARCHAR(18)
         , @c_Lottable02   NVARCHAR(18)
         , @dt_lottable04  DATETIME
            

   CREATE Table #TempKIT11
      (  KitKey            NVARCHAR(10) NULL
      ,  Storerkey         NVARCHAR(15) NULL
      ,  KDType            NVARCHAR(10) NULL
      ,  Sku               NVARCHAR(20) NULL
      ,  Loc               NVARCHAR(10) NULL 
      ,  Qty               INT          NULL DEFAULT (0) 
      ,  invqty            INT          NULL DEFAULT (0) 
      ,  Lottable02        NVARCHAR(18) NULL
      ,  Lottable04        DATETIME NULL--NVARCHAR(18) NULL
      ,  Lottable01        NVARCHAR(50) NULL
      ,  SKUDESCR          NVARCHAR(250) NULL
      ,  Remarks           NVARCHAR(200) NULL
     -- ,  Balqty            INT           NULL DEFAULT (0) 
      )
  

   INSERT INTO #TempKIT11
         (  KitKey             
         ,  Storerkey    
         ,  KDType      
         ,  Sku                       
         ,  Loc               
         ,  Qty 
         ,  invQty                 
         ,  Lottable02         
         ,  Lottable04
         ,  Lottable01
         ,  SKUDESCR
         ,  Remarks         
     --    ,  BalqtyQty 
         )
   SELECT @c_kitkey
        , KIT.StorerKey  
        , KITDETAIL.type
        , KITDETAIL.SKU 
        , KITDETAIL.Loc
        , SUM(KITDETAIL.Qty)
        , SUM(lli.Qty)
        , ISNULL(RTRIM(KITDETAIL.Lottable02),'')
        , ISNULL(RTRIM(KITDETAIL.Lottable04),'')--CONVERT(NVARCHAR(10),ISNULL(RTRIM(KITDETAIL.Lottable04),''),111)
        , ''--ISNULL(RTRIM(KITDETAIL.Lottable01),'')
        , ISNULL(S.DESCR,'')
        , KIT.remarks
   FROM  KITDETAIL WITH (NOLOCK)
   JOIN  KIT       WITH (NOLOCK) ON (KITDETAIL.Kitkey = KIT.Kitkey)
   JOIN LOTxLOCxID lli WITH (NOLOCK) ON lli.sku = KITDETAIL.sku AND lli.lot = KITDETAIL.lot
                                     AND lli.loc = KITDETAIL.loc AND lli.id =KITDETAIL.id AND lli.StorerKey=KITDETAIL.storerkey 
   JOIN SKU S WITH (NOLOCK) ON s.StorerKey = KITDETAIL.Storerkey AND S.sku = KITDETAIL.sku 
   WHERE KIT.Kitkey     = @c_kitkey         
   GROUP BY KIT.StorerKey  
         ,  KITDETAIL.SKU
         ,  KITDETAIL.type
         ,  KITDETAIL.Loc
         ,  ISNULL(RTRIM(KITDETAIL.Lottable02),'')
         ,  ISNULL(RTRIM(KITDETAIL.Lottable04),'')   
         --, CONVERT(NVARCHAR(10),ISNULL(RTRIM(KITDETAIL.Lottable04),''),111)
         --, ISNULL(RTRIM(KITDETAIL.Lottable01),'')
         , ISNULL(S.DESCR,'')
         , KIT.remarks
   ORDER BY KITDETAIL.SKU,ISNULL(RTRIM(KITDETAIL.Lottable02),'')

   QUIT:
   SELECT   KitKey             
         ,  Storerkey    
         ,  KDType      
         ,  Sku                       
         ,  Loc               
         ,  Qty 
         ,  invQty                 
         ,  Lottable02         
         ,  CONVERT(NVARCHAR(10),Lottable04,111) AS Lottable04
         ,  Lottable01
         ,  SKUDESCR
         ,  Remarks 
         ,  (invqty - qty) AS balqty 
   FROM  #TempKIT11 TMPK11
  ORDER BY Sku
         , Lottable02
   
  Drop Table #TempKIT11
END

GO