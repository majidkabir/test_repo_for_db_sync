SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_ConsoPickList44                                */  
/* Creation Date:  03-Jun-2020                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  CSCHONG                                                 */  
/*                                                                      */  
/* Purpose: WMS-13542 [CN] Inditex_Conso Pickslip                       */  
/*                                                                      */  
/* Input Parameters:  @c_Loadkey  - (LoadKey)                           */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  Report                                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  r_dw_consolidated_pick44                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 08-JUL-20    CSCHONG   1.1   WMS-13542 revised field mapping (CS01)  */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ConsoPickList44]
            (@c_LoadKey NVARCHAR(10))  
AS  
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTranCnt   INT  
         , @n_continue       INT
         , @n_err            INT 
         , @b_Success        INT
         , @c_errmsg         NVARCHAR(255)
         , @c_PickHeaderKey  NVARCHAR(10)
         , @c_PrintedFlag    NVARCHAR(1)
         , @n_CntConsignee   NVARCHAR(5)
         , @c_Consigneekey    NVARCHAR(45)          --CS01

   SET @n_StartTranCnt  = @@TRANCOUNT  
   SET @n_Continue      = 1 
   SET @n_err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''
   SET @c_PickHeaderKey = ''
   SET @c_PrintedFlag   = 'N'

   /* Start Modification */ 
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  

   IF NOT EXISTS(
                 SELECT PickHeaderKey
                 FROM   PICKHEADER WITH (NOLOCK)
                 WHERE  ExternOrderKey = @c_Loadkey
                 AND    Zone = '7'
                )
   BEGIN
      SET @b_success = 0 

      EXECUTE nspg_GetKey 
            'PICKSLIP'
          , 9
          , @c_PickHeaderKey  OUTPUT
          , @b_success        OUTPUT
          , @n_err            OUTPUT
          , @c_errmsg         OUTPUT  

      IF @b_success<>1
      BEGIN
         SET @n_continue = 3
         GOTO QUIT
      END  
        
      SET @c_PickHeaderKey = 'P'+@c_PickHeaderKey  

      INSERT INTO PICKHEADER
        (PickHeaderKey ,ExternOrderKey,PickType,Zone)
      VALUES
        (@c_PickHeaderKey,@c_Loadkey,'1','7')  

      SET @n_err = @@ERROR  

      IF @n_err<>0
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 63501  
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                       + ': Insert Into PICKHEADER Failed. (isp_ConsoPickList44)'
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM   PickHeader WITH (NOLOCK)
      WHERE  ExternOrderKey = @c_Loadkey
      AND    Zone = '7'

      SET @c_PrintedFlag = 'Y'
   END  

   IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 63502  
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                   + ': Get LoadKey Failed. (isp_ConsoPickList44)'
      GOTO QUIT
   END  
   
  SET @n_CntConsignee = 0
  SET @c_Consigneekey = ''               --CS01

  SELECT @n_CntConsignee = COUNT(DISTINCT OH.consigneekey)
  FROM ORDERS OH WITH (NOLOCK) 
  WHERE OH.loadkey = @c_LoadKey

 --CS01 START
 IF @n_CntConsignee = 1
 BEGIN
   SELECT @c_Consigneekey = MAX(OH.consigneekey)
  FROM ORDERS OH WITH (NOLOCK) 
  WHERE OH.loadkey = @c_LoadKey
 END
 --CS01 END
  
   SELECT DISTINCT ISNULL(RTRIM(PickHeader.PickHeaderKey),'')
        , @c_PrintedFlag
        , CASE WHEN @n_CntConsignee > 1 THEN ISNULL(RTRIM(LoadPlan.LoadKey),'') ELSE '' END AS Loadkey
        , L.PickZone as PickZone
        , ISNULL(RTRIM(SKU.BUSR4),'') as BUSR4
        , ISNULL(RTRIM(SKU.SUSR2),'') as SUSR5
        , ISNULL(RTRIM(PickDetail.Storerkey),'') as storerkey
        , ISNULL(RTRIM(PickDetail.Sku),'') as sku
        , ISNULL(RTRIM(PickDetail.Loc),'') as loc
        , sum(ISNULL(PickDetail.Qty,0)) as qty
        , ((ISNULL(sl.qty,0)) - ISNULL(sl.QtyAllocated,0)- ISNULL(sl.QtyPicked,0))  as slqty      --CS01
        , @c_Consigneekey AS Consigneekey 
   FROM  PickHeader WITH (NOLOCK)
   INNER JOIN LoadPlan WITH (NOLOCK)
    ON  (LoadPlan.LoadKey=PICKHEADER.ExternOrderKey)
   INNER JOIN LoadPlanDetail WITH (NOLOCK)
    ON  (LoadPlanDetail.LoadKey=LoadPlan.LoadKey)
   INNER JOIN PickDetail WITH (NOLOCK)
    ON  (PickDetail.OrderKey=LoadPlanDetail.OrderKey)
   INNER JOIN SKU WITH (NOLOCK)
    ON  (SKU.StorerKey=PickDetail.Storerkey)
   AND   (SKU.Sku=PickDetail.Sku)
   INNER JOIN LOC L WITH (NOLOCK)
    ON  (L.Loc = PickDetail.Loc)
   INNER JOIN skuxloc sl WITH (NOLOCK)
    ON  (sl.sku = PickDetail.sku and sl.storerkey = pickdetail.storerkey and sl.loc=pickdetail.loc)
   WHERE  PickHeader.PickHeaderKey = @c_PickHeaderKey
   AND    PickDetail.QTY>0 
   group by ISNULL(RTRIM(PickHeader.PickHeaderKey),'')
        , ISNULL(RTRIM(LoadPlan.LoadKey),'') 
        , L.PickZone 
        , ISNULL(RTRIM(SKU.BUSR4),'') 
        , ISNULL(RTRIM(SKU.SUSR2),'') 
        , ISNULL(RTRIM(PickDetail.Storerkey),'') 
        , ISNULL(RTRIM(PickDetail.Sku),'')
        , ISNULL(RTRIM(PickDetail.Loc),'') 
     --   , SUM(ISNULL(PickDetail.Qty,0)) as qty
        ,  ((ISNULL(sl.qty,0)) - ISNULL(sl.QtyAllocated,0)- ISNULL(sl.QtyPicked,0))      --CS01
   ORDER BY CASE WHEN @n_CntConsignee > 1 THEN ISNULL(RTRIM(LoadPlan.LoadKey),'') ELSE '' END
          , L.PickZone
          , ISNULL(RTRIM(PickDetail.Loc),'')
          , ISNULL(RTRIM(PickDetail.Sku),'')


   QUIT:
   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList44' 
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1  
      WHILE @@TRANCOUNT>@n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END 
      RETURN
   END
END /* main procedure */  

GO