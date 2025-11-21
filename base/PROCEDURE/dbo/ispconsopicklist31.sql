SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  ispConsoPickList31                                 */  
/* Creation Date:  23-Sep-2011                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  YTWan                                                   */  
/*                                                                      */  
/* Purpose: SOS#225976 - Umbro Consolidate pick slip                    */  
/*           (modified from nspConsoPickList29                          */  
/* Input Parameters:  @c_LoadKey  - (LoadKey)                           */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  Report                                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  r_dw_consolidated_pick31_2                               */  
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
  
CREATE PROC [dbo].[ispConsoPickList31](@c_LoadKey NVARCHAR(10))  
AS  
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_continue       INT
         , @n_StartTranCnt   INT  
         , @n_err            INT 
         , @b_success        INT
         , @c_PickHeaderKey  NVARCHAR(10)
         , @c_errmsg         NVARCHAR(255)


   SET @n_StartTranCnt = @@TRANCOUNT  
   SET @n_continue = 1 

   /* Start Modification */ 
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
   SET @c_PickHeaderKey = ''  

   IF NOT EXISTS(
        SELECT PickHeaderKey
        FROM   PICKHEADER WITH (NOLOCK)
        WHERE  ExternOrderKey = @c_LoadKey
        AND    Zone = '7'
    )
   BEGIN
      SET @b_success = 0 

      EXECUTE nspg_GetKey 
      'PICKSLIP', 
      9, 
      @c_PickHeaderKey OUTPUT, 
      @b_success OUTPUT, 
      @n_err OUTPUT, 
      @c_errmsg OUTPUT  
     
      IF @b_success<>1
      BEGIN
         SET @n_continue = 3
      END  
     
      IF @n_continue=1
      OR @n_continue=2
      BEGIN
         SET @c_PickHeaderKey = 'P'+@c_PickHeaderKey  

         INSERT INTO PICKHEADER
           (PickHeaderKey ,ExternOrderKey,PickType,Zone)
         VALUES
           (@c_PickHeaderKey,@c_LoadKey,'1','7')  

         SET @n_err = @@ERROR  

         IF @n_err<>0
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 63501  
            SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                        + ': Insert Into PickHeader Failed. (ispConsoPickList31)'
         END
      END-- @n_continue = 1 or @n_continue = 2
   END
   ELSE
   BEGIN
      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM   PickHeader WITH (NOLOCK)
      WHERE  ExternOrderKey = @c_LoadKey
      AND    Zone = '7'
   END  

   IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 63502  
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                   + ': Get LoadKey Failed. (ispConsoPickList31)'
   END  

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT Loadkey = ISNULL(RTRIM(LoadPlan.LoadKey),'')
            ,PickHeaderKey  = ISNULL(RTRIM(PickHeader.PickHeaderKey),'')
            ,AddDate        = LoadPlan.AddDate
            ,Facility       = ISNULL(RTRIM(Orders.Facility),'')
            ,TotalQtyOrdered=(
                               SELECT ISNULL(SUM(OriginalQty),0)
                               FROM   OrderDetail WITH (NOLOCK)
                               WHERE  OrderDetail.Loadkey = ISNULL(RTRIM(LoadPlan.LoadKey),'')
                            )
            ,AllocFromBulk  = CASE ISNULL(RTRIM(PickDetail.UOM),'') WHEN '2' THEN ISNULL(PickDetail.Qty,0) ELSE 0 END
            ,AllocFromPick  = CASE ISNULL(RTRIM(PickDetail.UOM),'') WHEN '6' THEN ISNULL(PickDetail.Qty,0) ELSE 0 END                               
            ,Loc            = ISNULL(RTRIM(PickDetail.Loc),'')
            ,Sku            = ISNULL(RTRIM(PickDetail.Sku),'')
            ,Qty            = ISNULL(PickDetail.Qty,0)
            ,Descr          = ISNULL(RTRIM(Sku.Descr),'')
            ,Size           = ISNULL(RTRIM(Sku.Size),'')
            ,CaseCnt        = ISNULL(Pack.CaseCnt,0)
            ,PackKey        = ISNULL(RTRIM(Pack.PackKey),'')   
      FROM   LoadPlan WITH (NOLOCK)
      INNER JOIN PickHeader WITH (NOLOCK)
      ON  (PickHeader.ExternOrderKey=LoadPlan.LoadKey)
      INNER JOIN LoadPlanDetail WITH (NOLOCK)
      ON  (LoadPlanDetail.LoadKey=LoadPlan.LoadKey)
      INNER JOIN ORDERS WITH (NOLOCK)
      ON  (Orders.OrderKey=LoadPlanDetail.OrderKey)
      INNER JOIN PickDetail WITH (NOLOCK)
      ON  (PickDetail.OrderKey=Orders.OrderKey)
      INNER JOIN SKU WITH (NOLOCK)
      ON  (Sku.StorerKey=PickDetail.Storerkey)
      AND (Sku.Sku=PickDetail.Sku)
      INNER JOIN Pack WITH (NOLOCK)
      ON  (Pack.PackKey=Sku.PackKey)
      INNER JOIN Loc WITH (NOLOCK)
      ON  (Loc.Loc=PickDetail.loc)
      WHERE  PickHeader.PickHeaderKey = @c_PickHeaderKey
      AND    PickDetail.Qty > 0 
      ORDER BY ISNULL(RTRIM(PickDetail.UOM),'')
            ,  ISNULL(RTRIM(Loc.LogicalLocation),'')
            ,  ISNULL(RTRIM(PickDetail.Loc),'')
            ,  ISNULL(RTRIM(PickDetail.Sku),'')

   END -- @n_continue = 1 or @n_continue = 2  


   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispConsoPickList31' 
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