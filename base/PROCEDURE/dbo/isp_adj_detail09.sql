SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_ADJ_Detail09                                        */  
/* Creation Date: 20-DEC-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: WMS-779 - SHISEIDO - Adjustment Ticket                      */  
/*        :                                                             */  
/* Called By:  r_adjustment_detail09                                    */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 10-MAR-2017  JayLim   1.1  SQL2012 compatibility modification (Jay01)*/  
/************************************************************************/  
CREATE PROC [dbo].[isp_ADJ_Detail09]  
           @c_AdjustmentKey   NVARCHAR(10)  
         , @c_userid          NVARCHAR(30)     
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
  
         , @c_Storerkey       NVARCHAR(15)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   CREATE TABLE #TMP_REASON  
      (  ListName    NVARCHAR(10)  
      ,  Code        NVARCHAR(30)  
      ,  Description NVARCHAR(60)  
      )  
  
   SET @c_Storerkey = ''  
   SELECT @c_Storerkey = Storerkey  
   FROM ADJUSTMENT WITH (NOLOCK)  
   WHERE AdjustmentKey = @c_AdjustmentKey   
  
  
   IF NOT EXISTS ( SELECT 1  
                   FROM CODELKUP WITH (NOLOCK)  
                   WHERE ListName = 'ADJREASON'  
                   AND   Storerkey= @c_Storerkey  
                  )  
   BEGIN  
      SET @c_Storerkey = ''  
   END   
  
   INSERT INTO #TMP_REASON  
      (  ListName   
      ,  Code  
      ,  Description  
      )  
   SELECT ListName  
      ,   Code  
      ,   Description = ISNULL(RTRIM(Description),'')  
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'ADJREASON'  
   AND   Storerkey= @c_Storerkey  
     
   SELECT ADJUSTMENT.AdjustmentKey     
         ,ADJUSTMENT.StorerKey    
         ,ADJUSTMENT.AdjustmentType     
         ,ADJUSTMENT.CustomerRefNo   
         ,ADJUSTMENT.FromToWhse     
         ,ADJUSTMENT.Remarks  
         ,ADJUSTMENT.EffectiveDate  
         ,ADJUSTMENT.Facility  
         ,ADJUSTMENT.UserDefine01  
         ,ADJUSTMENT.UserDefine02  
         ,ADJUSTMENT.UserDefine03  
         ,ADJUSTMENT.UserDefine04  
         ,ADJUSTMENT.UserDefine05  
         ,ADJUSTMENT.UserDefine06  
         ,ADJUSTMENT.UserDefine07  
         ,ADJUSTMENT.UserDefine08  
         ,ADJUSTMENT.UserDefine09  
         ,ADJUSTMENT.UserDefine10   
         ,ADJUSTMENT.FinalizedFlag   
         ,ADJUSTMENT.DocType  
         ,ADJUSTMENTDETAIL.AdjustmentLineNumber     
         ,ADJUSTMENTDETAIL.Sku  
         ,ADJUSTMENTDETAIL.Lot  
         ,ADJUSTMENTDETAIL.Loc  
         ,ADJUSTMENTDETAIL.ID  
         ,ADJUSTMENTDETAIL.packkey  
         ,ADJUSTMENTDETAIL.ReasonCode + '-' + ISNULL(RTRIM(ADJR.Description),'')  
         ,ADJUSTMENTDETAIL.Qty     
         ,ADJUSTMENTDETAIL.PackKey     
         ,ADJUSTMENTDETAIL.UOM    
         ,ADJUSTMENTDETAIL.Qty   
         ,UOMQTY = (ADJUSTMENTDETAIL.Qty /  
                   CASE ADJUSTMENTDETAIL.UOM  
                     WHEN PACK.PACKUOM1 THEN PACK.CaseCnt  
                     WHEN PACK.PACKUOM2 THEN PACK.InnerPack  
                     WHEN PACK.PACKUOM3 THEN 1  
                     WHEN PACK.PACKUOM4 THEN PACK.Pallet  
                     WHEN PACK.PACKUOM5 THEN PACK.[Cube]  
                     WHEN PACK.PACKUOM6 THEN PACK.GrossWgt  
                     WHEN PACK.PACKUOM7 THEN PACK.NetWgt  
                     WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1  
                     WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2  
                     END)   
         ,SKU.Descr  
         ,SKU.ManufacturerSku  
         ,LOTATTRIBUTE.Lottable01  
         ,LOTATTRIBUTE.Lottable02  
         ,LOTATTRIBUTE.Lottable03  
         ,LOTATTRIBUTE.Lottable04  
         ,LOTATTRIBUTE.Lottable05  
    FROM ADJUSTMENT       WITH (NOLOCK)   
    JOIN ADJUSTMENTDETAIL WITH (NOLOCK) ON (ADJUSTMENT.Adjustmentkey = ADJUSTMENTDETAIL.Adjustmentkey)  
    JOIN SKU  WITH (NOLOCK) ON ( ADJUSTMENTDETAIL.Storerkey = SKU.Storerkey)  
          AND( ADJUSTMENTDETAIL.Sku = SKU.Sku)  
  JOIN PACK WITH (NOLOCK) ON ( SKU.PackKey = Pack.PackKey )  
    JOIN #TMP_REASON  ADJR   WITH (NOLOCK) ON  ( ADJR.ListName = 'ADJREASON' )  
                                           AND ( ADJR.Code     =  ADJUSTMENTDETAIL.ReasonCode )  
    LEFT JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( ADJUSTMENTDETAIL.Lot = LOTATTRIBUTE.Lot)  
    WHERE ADJUSTMENT.AdjustmentKey = @c_Adjustmentkey  
END -- procedure  

GO