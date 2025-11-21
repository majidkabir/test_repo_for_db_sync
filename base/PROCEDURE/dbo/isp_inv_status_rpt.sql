SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: isp_inv_status_rpt                                          */  
/* Creation Date: 18-FEB-20156                                          */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:SOS#363444-FrieslandHK-FC Availability Date                  */
/*                               (lottable13) builder                   */  
/* Called By: r_inv_status_rpt                                          */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_inv_status_rpt]  
            @c_storerKey      NVARCHAR(15)  
         ,  @b_Success        INT = 1  OUTPUT   
         ,  @n_err            INT = 0  OUTPUT   
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT  
AS  
BEGIN  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
         , @c_AdjLineNumber   NVARCHAR(5)  
        -- , @c_Storerkey       NVARCHAR(15)  
         , @c_Sku             NVARCHAR(20)  
         , @c_UserDefine02    NVARCHAR(20)  
  
         , @c_prefix          NVARCHAR(2)  
         , @c_FCBatchNo       NVARCHAR(5)  
         , @c_Lot02           NVARCHAR(18)  
         , @c_Lot             NVARCHAR(10)  
         , @c_Lottable01   NVARCHAR(18)      
         , @c_Lottable02   NVARCHAR(18)     
         , @c_Lottable03   NVARCHAR(18)      
         , @dt_Lottable04  DATETIME         
         , @dt_Lottable05  DATETIME         
         , @c_Lottable06   NVARCHAR(30)     
         , @c_Lottable07   NVARCHAR(30)      
         , @c_Lottable08   NVARCHAR(30)      
         , @c_Lottable09   NVARCHAR(30)     
         , @c_Lottable10   NVARCHAR(30)     
         , @c_Lottable11   NVARCHAR(30)     
         , @c_Lottable12   NVARCHAR(30)      
         , @dt_Lottable13  DATETIME         
         , @dt_Lottable14  DATETIME         
         , @dt_Lottable15  DATETIME    
  
         , @c_Recipients      NVARCHAR(1000)  
         , @c_Subject         NVARCHAR(250)  
         , @c_Body            NVARCHAR(1000) 

         , @c_busr4           NVARCHAR(18)  
         , @c_susr2           NVARCHAR(18)  
         , @dt_GetLottable13  DATETIME 
     
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
    
   
   CREATE TABLE #TEMP_INVSTATUS
       ( SKUGroup         NVARCHAR(10) NULL,
         lottable01       NVARCHAR(18) NULL,
         lottable03       NVARCHAR(18) NULL,
         loc              NVARCHAR(10) NULL,
         SKU              NVARCHAR(20) NULL,
         busr4            NVARCHAR(200) NULL,
         SkuDesc          NVARCHAR(60)  NULL,
         Cntqty           NVARCHAR(20) NULL,
         lottable02       NVARCHAR(18) NULL,
         qty              INT,
         QtyAllocated     INT,
         QtyPicked        INT, 
         ReorderQty       INT, 
         lottable05       NVARCHAR(10),
         Alertflag        NVARCHAR(20))
   
   INSERT INTO #TEMP_INVSTATUS (
   SKUGroup,lottable01,lottable03,SKU,busr4,SkuDesc,loc,Cntqty,
   lottable02,qty,QtyAllocated,QtyPicked,ReorderQty,lottable05,Alertflag
   )
   SELECT S.SKUGroup,l.lottable01,l.Lottable03,lli.sku,
       ISNULL(s.busr4,''),s.DESCR,lli.loc,Substring(S.Packkey,5,len(S.Packkey)),
       l.Lottable02,lli.qty,lli.QtyAllocated,lli.QtyPicked,ISNULL(s.ReorderQty,0),
       ISNULL(CONVERT(NVARCHAR(10),l.Lottable05,120),''),
      CASE WHEN (lli.Qty-lli.QtyAllocated-lli.QtyPicked)<S.ReorderQty
      Then 'Alert' ELSE
      CASE WHEN (lli.Qty-lli.QtyAllocated-lli.QtyPicked)>=S.ReorderQty or Isnull(S.ReorderQty,'')='' or S.ReorderQty in ('','0')
      Then ' ' END
      END
		FROM LOTxLOCxID AS lli WITH (NOLOCK)
		JOIN SKU S WITH (NOLOCK) ON S.sku=lli.Sku AND s.StorerKey = lli.StorerKey
		JOIN LOTATTRIBUTE AS l WITH (NOLOCK) ON l.lot=lli.Lot
		WHERE lli.storerkey=@c_storerKey 
   ORDER BY lli.sku,l.Lottable03, ISNULL(CONVERT(NVARCHAR(10),l.Lottable05,120),''),lli.loc
  
  
  
  SELECT * FROM #TEMP_INVSTATUS
  ORDER BY sku,lottable03,lottable05,loc
  
  
  DROP Table #TEMP_INVSTATUS
   
QUIT_SP:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_AD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_AD  
      DEALLOCATE CUR_AD  
   END  
  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ADLINE') in (0 , 1)    
   BEGIN  
      CLOSE CUR_ADLINE  
      DEALLOCATE CUR_ADLINE  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_inv_status_rpt'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure

GO